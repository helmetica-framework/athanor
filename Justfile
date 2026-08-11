import "Justfile.vars.just"

_default:
    @just --list

# Start up athanor
ignite: kind-setup metallb-setup traefik-setup prometheus-setup k8up-setup certmanager-setup registry-setup

# Stop and delete all docker containers of athanor
quench: kind-clean

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

# Install internal container registry (localhost:5000) into kind
registry-setup $KUBECONFIG=kind_kubeconfig: certmanager-setup
    kubectl apply -f hearth/registry/registry.yaml
    kubectl -n kube-system wait --for condition=Ready certificate/registry-cert --timeout 120s
    kubectl -n kube-system wait --for condition=Available deployment/registry --timeout 120s
