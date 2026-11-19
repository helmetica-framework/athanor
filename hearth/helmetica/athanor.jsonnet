local alembic = import 'alembic/lib/alembic.libsonnet';

function(settings)
  local rendered = alembic.framework(settings);
  local monitoring = alembic.monitoring(settings);

  local isDeployment(name) =
    function(o) o.kind == 'Deployment' && o.metadata.name == name;

  local trustBundle(c) =
    c {
      volumeMounts+: [ { name: 'trust-bundle', mountPath: '/etc/trust', readOnly: true } ],
      env+: [ { name: 'SSL_CERT_FILE', value: '/etc/trust/ca-certificates.crt' } ],
    };

  local flux(o) =
    if isDeployment('source-controller')(o) ||
       isDeployment('helm-controller')(o) ||
       isDeployment('image-reflector-controller')(o)
    then o {
      spec+: { template+: { spec+: {
        volumes+: [ { name: 'trust-bundle', configMap: { name: 'athanor-trust-bundle' } } ],
        containers: [
          if c.name == 'manager' then trustBundle(c) else c
          for c in o.spec.template.spec.containers
        ],
      } } },
    }
    else o;

  local ampulla(o) =
    if isDeployment('ampulla-controller-manager')(o)
    then o {
      spec+: { template+: { spec+: {
        containers: [
          if c.name == 'manager' then c {
            args+: [ '--default-bucket-class=garage', '--default-bucket-access-class=garage' ],
          } else c
          for c in o.spec.template.spec.containers
        ],
      } } },
    }
    else o;

  local chrysopoeia(o) =
    if isDeployment('chrysopoeia-controller-manager')(o)
    then o {
      spec+: { template+: { spec+: {
        containers: [
          if c.name == 'manager' then c {
            resources: std.get(c, 'resources', {}) + {
              limits: std.get(std.get(c, 'resources', {}), 'limits', {}) + { memory: '256Mi' },
            },
            env+: [ {
              name: 'GOMEMLIMIT',
              valueFrom: { resourceFieldRef: { resource: 'limits.memory' } },
            } ],
          } else c
          for c in o.spec.template.spec.containers
        ],
      } } },
    }
    else o;

  local patched = {
    [file]: [ chrysopoeia(ampulla(flux(m))) for m in rendered[file] ]
    for file in std.objectFields(rendered)
  };

  local bucketClaim = {
    apiVersion: 'objectstorage.k8s.io/v1alpha2',
    kind: 'BucketClaim',
    metadata: {
      name: 'libra-billing',
      namespace: 'syn-helmetica-framework',
    },
    spec: {
      bucketClassName: 'garage',
      protocols:
        [ 'S3' ],
    },
  };

  local bucketAccess = {
    apiVersion: 'objectstorage.k8s.io/v1alpha2',
    kind: 'BucketAccess',
    metadata: {
      name: 'libra-billing',
      namespace: 'syn-helmetica-framework',
    },
    spec: {
      bucketAccessClassName: 'garage',
      protocol: 'S3',
      bucketClaims: [
        {
          bucketClaimName: 'libra-billing',
          accessMode: 'ReadWrite',
          accessSecretName: 'libra-billing',
        },
      ],
    },
  };

  local platformValues = {
    'io.vshn.cluster/v1alpha1': {
      name: 'athanor',
    },
  };

  local platformCluster = {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      annotations: {
        'chrysopoeia.io/platform-values': '0',
      },
      labels: {
        name: 'platform-cluster',
      },
      name: 'platform-cluster',
      namespace: 'syn-helmetica-framework',
    },
    data: {
      'values.json': std.toString(platformValues),
    },
  };

  {
    ['framework/%s.yaml' % k]: std.manifestYamlStream(patched[k], quote_keys=false)
    for k in std.objectFields(patched)
  } + {
    ['monitoring/%s.yaml' % k]: std.manifestYamlStream(monitoring[k], quote_keys=false)
    for k in std.objectFields(monitoring)
  } + {
    'extras/bucket.yaml': std.manifestYamlStream([ bucketClaim, bucketAccess ], quote_keys=false),
    'extras/platform-cluster.yaml': std.manifestYamlStream([ platformCluster ], quote_keys=false),
  }
