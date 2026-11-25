{
  namespace: 'syn-helmetica-framework',
  namespaceMetadata: {
    labels: {
      'pod-security.kubernetes.io/enforce': 'restricted',
    },
  },
  monitoring_stack: {
    enabled: true,
    platform: 'kind',
    namespace: 'syn-helmetica-framework-monitoring',
    alertmanager: { replicas: 1 },
    crds: { enabled: true },
  },
}
