cluster_dir ?= $(PWD)/.kind
go_bin ?= $(PWD)/.work/bin
$(go_bin):
	@mkdir -p $@

# Kind
# renovate: datasource=docker depName=kindest/node
KIND_NODE_VERSION ?= v1.36.1
# renovate: datasource=github-releases depName=kubernetes-sigs/kind
KIND_VERSION ?= v0.32.0
KIND_IMAGE ?= docker.io/kindest/node:$(KIND_NODE_VERSION)
KIND_CMD ?= go run sigs.k8s.io/kind
KIND_KUBECONFIG ?= $(cluster_dir)/kind-kubeconfig-$(KIND_NODE_VERSION)
KIND_CLUSTER ?= athanor
DOCKER_CONTAINER ?= athanor-control-plane
DOCKER_NETWORK ?= kind

# Module versions
# renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
TRAEFIK_CHART_VERSION ?= 41.0.2
# renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
PROMETHEUS_CHART_VERSION ?= 87.5.1
# renovate: datasource=helm depName=k8up registryUrl=https://k8up-io.github.io/k8up
K8UP_CHART_VERSION ?= 4.9.0
# renovate: datasource=github-releases depName=k8up-io/k8up
K8UP_CRD_VERSION ?= v2.15.0
# renovate: datasource=github-releases depName=cert-manager/cert-manager
CERTMANAGER_VERSION ?= v1.20.3
# renovate: datasource=github-releases depName=metallb/metallb
METALLB_VERSION ?= v0.16.0

# PROMETHEUS
PROM_VALUES=hearth/prometheus/values.yaml

# Sentinels
k8up_sentinel = $(cluster_dir)/k8up_sentinel
prometheus_sentinel = $(cluster_dir)/prometheus_sentinel
certmanager_sentinel = $(cluster_dir)/certmanager_sentinel
metallb_sentinel = $(cluster_dir)/metallb_sentinel
traefik_sentinel = $(cluster_dir)/traefik_sentinel
registry_sentinel = $(cluster_dir)/registry_sentinel
