SHELL:=/bin/bash

.DEFAULT_GOAL := help

# General variables
include Makefile.vars.mk

# Kind
include hearth/kind/kind.mk

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ignite
ignite: kind metallb-setup traefik-setup prometheus-setup k8up-setup certmanager-setup registry-setup ## Start up athanor

.PHONY: quench
quench: kind-clean ## Stop and delete all docker containers of athanor

.PHONY: prometheus-setup
prometheus-setup: $(prometheus_sentinel) ## Install prometheus stack

$(prometheus_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(prometheus_sentinel): $(KIND_KUBECONFIG) $(PROM_VALUES)
	helm upgrade --install kube-prometheus \
		--repo https://prometheus-community.github.io/helm-charts \
		--version $(PROMETHEUS_CHART_VERSION) \
		--create-namespace \
		--namespace prometheus-system \
		--wait \
		--values ${PROM_VALUES} \
		kube-prometheus-stack
	kubectl -n prometheus-system wait --for condition=Available deployment/kube-prometheus-kube-prome-operator --timeout 120s
	@touch $@

.PHONY: traefik-setup
traefik-setup: $(traefik_sentinel) ## Install traefik as ingress controller into kind

$(traefik_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(traefik_sentinel): $(KIND_KUBECONFIG) hearth/traefik/values.yaml
	helm upgrade --install traefik \
		--repo https://traefik.github.io/charts \
		--version $(TRAEFIK_CHART_VERSION) \
		--create-namespace \
		--namespace traefik \
		--wait \
		--values hearth/traefik/values.yaml \
		traefik
	kubectl -n traefik wait --for condition=Available deployment/traefik --timeout 120s
	@touch $@

.PHONY: k8up-setup
k8up-setup: $(k8up_sentinel) ## Install k8up into kind

$(k8up_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(k8up_sentinel): $(KIND_KUBECONFIG) hearth/k8up/values.yaml
	kubectl apply -f https://github.com/k8up-io/k8up/releases/download/$(K8UP_CRD_VERSION)/k8up-crd.yaml --server-side
	helm upgrade --install k8up \
		--repo https://k8up-io.github.io/k8up \
		--version $(K8UP_CHART_VERSION) \
		--create-namespace \
		--namespace k8up-system \
		--wait \
		--values hearth/k8up/values.yaml \
		k8up
	kubectl -n k8up-system wait --for condition=Available deployment/k8up --timeout 60s
	@touch $@

.PHONY: certmanager-setup
certmanager-setup: $(certmanager_sentinel) ## Install certmanager into kind

$(certmanager_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(certmanager_sentinel): $(KIND_KUBECONFIG)
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERTMANAGER_VERSION)/cert-manager.yaml
	kubectl -n cert-manager wait --for condition=Available deployment/cert-manager --timeout 120s
	kubectl -n cert-manager wait --for condition=Available deployment/cert-manager-webhook --timeout 120s
	kubectl -n cert-manager wait --for condition=Available deployment/cert-manager-cainjector --timeout 120s
	@touch $@

.PHONY: registry-setup
registry-setup: $(registry_sentinel) ## Install internal container registry (localhost:5000) into kind

$(registry_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(registry_sentinel): $(KIND_KUBECONFIG) $(certmanager_sentinel) hearth/registry/registry.yaml
	kubectl apply -f hearth/registry/registry.yaml
	kubectl -n kube-system wait --for condition=Ready certificate/registry-cert --timeout 120s
	kubectl -n kube-system wait --for condition=Available deployment/registry --timeout 120s
	@touch $@

.PHONY: metallb-setup
metallb-setup: $(metallb_sentinel) ## Install metallb as loadbalancer

$(metallb_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(metallb_sentinel): $(KIND_KUBECONFIG) hearth/metallb/config.yaml
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/$(METALLB_VERSION)/config/manifests/metallb-native.yaml
	kubectl wait --namespace metallb-system \
		--for=condition=ready pod \
		--selector=app=metallb \
		--timeout=90s
	@echo "Waiting for metallb webhook to become ready..."
# The controller pod turns Ready before its webhook server listens (it waits
# for cert rotation first), so retry the apply until the webhook answers.
	HOSTIP=$$(docker inspect $(DOCKER_CONTAINER) | jq -r '.[0].NetworkSettings.Networks["kind"].Gateway') && \
	export range="$${HOSTIP}00-$${HOSTIP}50" && \
	ok=0; for i in $$(seq 1 30); do \
		if cat hearth/metallb/config.yaml | yq 'select(document_index == 0) | .spec.addresses = [strenv(range)]' | kubectl apply -f -; then ok=1; break; fi; \
		echo "metallb webhook not ready yet, retrying ($$i/30)..."; \
		sleep 3; \
	done; [ $$ok -eq 1 ]
	cat hearth/metallb/config.yaml | yq 'select(document_index == 1)' | kubectl apply -f -
	@touch $@
