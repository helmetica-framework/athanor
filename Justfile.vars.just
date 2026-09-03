cluster_dir := justfile_directory() / ".kind"
go_bin := justfile_directory() / ".work" / "bin"

# Kind
# renovate: datasource=docker depName=kindest/node
KIND_NODE_VERSION := "v1.36.1"
# renovate: datasource=github-releases depName=kubernetes-sigs/kind
KIND_VERSION := "v0.33.0"
KIND_IMAGE := "docker.io/kindest/node:" + KIND_NODE_VERSION
KIND_CMD := "go run sigs.k8s.io/kind@" + KIND_VERSION
# renovate: datasource=go depName=sigs.k8s.io/kustomize/kustomize/v5
KUSTOMIZE_VERSION := "v5.8.1"
KUSTOMIZE_CMD := "go run sigs.k8s.io/kustomize/kustomize/v5@" + KUSTOMIZE_VERSION
kind_kubeconfig    := justfile_directory() / ".kind/kind-config"
KIND_CLUSTER := "athanor"
DOCKER_CONTAINER := "athanor-control-plane"
DOCKER_NETWORK := "kind"

# Module versions
# renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
TRAEFIK_CHART_VERSION := "41.4.0"
# renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
PROMETHEUS_CHART_VERSION := "88.6.3"
# renovate: datasource=helm depName=k8up registryUrl=https://k8up-io.github.io/k8up
K8UP_CHART_VERSION := "4.10.0"
# renovate: datasource=github-releases depName=k8up-io/k8up
K8UP_CRD_VERSION := "v2.16.0"
# renovate: datasource=github-releases depName=cert-manager/cert-manager
CERTMANAGER_VERSION := "v1.21.1"
# renovate: datasource=github-releases depName=metallb/metallb
METALLB_VERSION := "v0.16.0"
# renovate: datasource=docker depName=ghcr.io/rajsinghtech/charts/garage-operator
GARAGE_OPERATOR_CHART_VERSION := "0.7.6"
# The COSI API itself: CRDs and the central controller, neither of which is released as a
# tag that carries the v1alpha2 API yet. Pinned to the revision the garage operator's COSI
# client is built against (its go.mod), so bump it together with the chart above.
COSI_REVISION := "cc544691e2ef7ddc2fba972d796ed3188ea46315"

# PROMETHEUS
PROM_VALUES := "hearth/prometheus/values.yaml"
