import "Justfile.vars.just"

_default:
    @just --list

# Start up athanor
ignite: digest helmetica-setup

# Stop and delete all docker containers of athanor
quench: kind-clean

# Provision cluster without helmetica. Derived from digestio: holding something at a low warmth
digest: kind-setup metallb-setup traefik-setup prometheus-setup k8up-setup certmanager-setup cosi-setup garage-setup registry-setup

# Create the kind cluster
kind-setup $KUBECONFIG=kind_kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$(dirname "$KUBECONFIG")"
    if ! {{ KIND_CMD }} get clusters 2>/dev/null | grep -qx {{ KIND_CLUSTER }}; then
    	{{ KIND_CMD }} create cluster \
    		--name {{ KIND_CLUSTER }} \
    		--image {{ KIND_IMAGE }} \
    		--config hearth/kind/config.yaml
    fi
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master- || true
    kubectl version
    kubectl cluster-info
    kubectl config use-context kind-{{ KIND_CLUSTER }}
    echo =======
    echo "Setup finished. To interact with the local dev cluster, set the KUBECONFIG environment variable as follows:"
    echo "export KUBECONFIG=$(realpath "$KUBECONFIG")"
    echo =======

# Remove the kind cluster
kind-clean $KUBECONFIG=kind_kubeconfig:
    -{{ KIND_CMD }} delete cluster --name {{ KIND_CLUSTER }}
    rm -rf {{ cluster_dir }}

# Install metallb as loadbalancer
metallb-setup $KUBECONFIG=kind_kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/{{ METALLB_VERSION }}/config/manifests/metallb-native.yaml
    kubectl wait --namespace metallb-system \
    	--for=condition=ready pod \
    	--selector=app=metallb \
    	--timeout=90s
    echo "Waiting for metallb webhook to become ready..."
    # The controller pod turns Ready before its webhook server listens (it waits
    # for cert rotation first), so retry the apply until the webhook answers.
    HOSTIP=$(docker inspect {{ DOCKER_CONTAINER }} | jq -r '.[0].NetworkSettings.Networks["{{ DOCKER_NETWORK }}"].Gateway')
    export range="${HOSTIP}00-${HOSTIP}50"
    ok=0
    for i in $(seq 1 30); do
    	if yq 'select(document_index == 0) | .spec.addresses = [strenv(range)]' hearth/metallb/config.yaml | kubectl apply -f -; then ok=1; break; fi
    	echo "metallb webhook not ready yet, retrying ($i/30)..."
    	sleep 3
    done
    [ $ok -eq 1 ]
    yq 'select(document_index == 1)' hearth/metallb/config.yaml | kubectl apply -f -

# Install certmanager into kind
certmanager-setup $KUBECONFIG=kind_kubeconfig:
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/{{ CERTMANAGER_VERSION }}/cert-manager.yaml
    kubectl -n cert-manager wait --for condition=Available deployment/cert-manager --timeout 120s
    kubectl -n cert-manager wait --for condition=Available deployment/cert-manager-webhook --timeout 120s
    kubectl -n cert-manager wait --for condition=Available deployment/cert-manager-cainjector --timeout 120s

# Install prometheus stack
prometheus-setup $KUBECONFIG=kind_kubeconfig:
    helm upgrade --install kube-prometheus \
        --repo https://prometheus-community.github.io/helm-charts \
        --version {{ PROMETHEUS_CHART_VERSION }} \
        --create-namespace \
        --namespace prometheus-system \
        --wait \
        --values {{ PROM_VALUES }} \
        kube-prometheus-stack
    kubectl -n prometheus-system wait --for condition=Available deployment/kube-prometheus-kube-prome-operator --timeout 120s

# Install traefik as ingress controller into kind
traefik-setup $KUBECONFIG=kind_kubeconfig:
    helm upgrade --install traefik \
        --repo https://traefik.github.io/charts \
        --version {{ TRAEFIK_CHART_VERSION }} \
        --create-namespace \
        --namespace traefik \
        --wait \
        --values hearth/traefik/values.yaml \
        traefik
    kubectl -n traefik wait --for condition=Available deployment/traefik --timeout 120s

# Install k8up into kind
k8up-setup $KUBECONFIG=kind_kubeconfig:
    kubectl apply -f https://github.com/k8up-io/k8up/releases/download/{{ K8UP_CRD_VERSION }}/k8up-crd.yaml --server-side
    helm upgrade --install k8up \
        --repo https://k8up-io.github.io/k8up \
        --version {{ K8UP_CHART_VERSION }} \
        --create-namespace \
        --namespace k8up-system \
        --wait \
        --values hearth/k8up/values.yaml \
        k8up
    kubectl -n k8up-system wait --for condition=Available deployment/k8up --timeout 60s

# Install the COSI API: its CRDs and the controller that turns a BucketClaim into a Bucket
cosi-setup $KUBECONFIG=kind_kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    for crd in buckets bucketclasses bucketclaims bucketaccessclasses bucketaccesses; do
    	kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/container-object-storage-interface/{{ COSI_REVISION }}/client/config/crd/objectstorage.k8s.io_$crd.yaml"
    done
    {{ KUSTOMIZE_CMD }} build "github.com/kubernetes-sigs/container-object-storage-interface/controller?ref={{ COSI_REVISION }}" | kubectl apply --server-side -f -
    kubectl -n container-object-storage-system wait --for condition=Available deployment/container-object-storage-controller --timeout 180s

# Install the garage operator and a single-node Garage cluster as the local S3 backend
garage-setup $KUBECONFIG=kind_kubeconfig: certmanager-setup cosi-setup
    #!/usr/bin/env bash
    set -euo pipefail
    helm upgrade --install garage-operator \
    	oci://ghcr.io/rajsinghtech/charts/garage-operator \
    	--version {{ GARAGE_OPERATOR_CHART_VERSION }} \
    	--create-namespace \
    	--namespace garage-system \
    	--wait \
    	--values hearth/garage/values.yaml
    kubectl -n garage-system wait --for condition=Available deployment/garage-operator --timeout 180s
    # Garage's admin API token. Generated once and left alone: rotating it on every ignite
    # would restart the cluster for no reason.
    if ! kubectl -n garage-system get secret garage-admin-token >/dev/null 2>&1; then
    	kubectl -n garage-system create secret generic garage-admin-token \
    		--from-literal=admin-token="$(head -c 32 /dev/urandom | base64 | tr -d '=+/')"
    fi
    kubectl apply --server-side -f hearth/garage/cluster.yaml
    echo "Waiting for the Garage cluster to come up..."
    for i in $(seq 1 60); do
    	if kubectl -n garage-system get pod -l garage.rajsingh.info/cluster=garage 2>/dev/null | grep -q .; then break; fi
    	sleep 2
    done
    kubectl -n garage-system wait --for condition=Ready pod -l garage.rajsingh.info/cluster=garage --timeout 240s
    kubectl apply --server-side -f hearth/garage/cosi.yaml

# Install internal container registry (localhost:5000) into kind
registry-setup $KUBECONFIG=kind_kubeconfig: certmanager-setup
    kubectl apply -f hearth/registry/registry.yaml
    kubectl -n kube-system wait --for condition=Ready certificate/registry-cert --timeout 120s
    kubectl -n kube-system wait --for condition=Available deployment/registry --timeout 120s

# Publish the registry CA plus the host's public roots as a trust bundle for flux
trustbundle-setup $KUBECONFIG=kind_kubeconfig: registry-setup
    #!/usr/bin/env bash
    set -euo pipefail
    bundle=$(mktemp)
    trap 'rm -f "$bundle"' EXIT
    cat /etc/ssl/certs/ca-certificates.crt > "$bundle"
    # Created here so the bundle can be placed before the flux module is applied. `just
    # ignite` is meant to be re-runnable, so this must not fail on an existing namespace.
    kubectl create ns hel-flux --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n kube-system get secret tls-server-certificate -o jsonpath='{.data.ca\.crt}' | base64 -d >> "$bundle"
    kubectl -n hel-flux create configmap athanor-trust-bundle \
        --from-file=ca-certificates.crt="$bundle" \
        --dry-run=client -o yaml | kubectl apply -f -

# Install the helmetica operators (adept, chrysopoeia, harness proxy, sigillum, ampulla) into kind
#
# garage and k8up are dependencies because of ampulla: it watches COSI's and k8up's CRDs and
# defaults every policy to the `garage` classes hearth/garage/cosi.yaml installs.
helmetica-setup $KUBECONFIG=kind_kubeconfig: certmanager-setup prometheus-setup registry-setup trustbundle-setup garage-setup k8up-setup
    {{ KUSTOMIZE_CMD }} build hearth/helmetica | kubectl apply --server-side -f -
    # Namespaces are set in hearth/helmetica/*/kustomization.yaml; keep these in sync.
    kubectl -n hel-flux wait --for condition=Available deployment --all --timeout 180s
    kubectl -n hel-adept wait --for condition=Available deployment/adept-controller-manager --timeout 120s
    kubectl -n hel-chrysopoeia wait --for condition=Available deployment/chrysopoeia-controller-manager --timeout 120s
    kubectl -n hel-chrysopoeia-proxy wait --for condition=Available deployment/chrysopoeia-proxy --timeout 120s
    kubectl -n hel-ampulla wait --for condition=Available deployment/ampulla-controller-manager --timeout 120s
