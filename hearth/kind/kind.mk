kind_bin = $(go_bin)/kind

# Prepare kind binary
$(kind_bin): export GOOS = $(shell go env GOOS)
$(kind_bin): export GOARCH = $(shell go env GOARCH)
$(kind_bin): export GOBIN = $(go_bin)
$(kind_bin): | $(go_bin)
	go install sigs.k8s.io/kind@$(KIND_VERSION)


.PHONY: kind
kind: export KUBECONFIG = $(KIND_KUBECONFIG)
kind: kind-setup ## All-in-one kind target

.PHONY: kind-setup
kind-setup: export KUBECONFIG = $(KIND_KUBECONFIG)
kind-setup: $(KIND_KUBECONFIG) ## Creates the kind cluster

.PHONY: kind-clean
kind-clean: export KUBECONFIG = $(KIND_KUBECONFIG)
kind-clean: $(kind_bin)
kind-clean: ## Removes the kind Cluster
	@$(kind_bin) delete cluster --name $(KIND_CLUSTER) || true
	rm -rf $(cluster_dir) $(kind_bin)

$(KIND_KUBECONFIG): export KUBECONFIG = $(KIND_KUBECONFIG)
$(KIND_KUBECONFIG): $(kind_bin)
	$(kind_bin) create cluster \
		--name $(KIND_CLUSTER) \
		--image $(KIND_IMAGE) \
		--config hearth/kind/config.yaml
	cp $(KIND_KUBECONFIG) $(cluster_dir)/kind-config
	kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master- || true
	@kubectl version
	@kubectl cluster-info
	@kubectl config use-context kind-$(KIND_CLUSTER)
	@echo =======
	@echo "Setup finished. To interact with the local dev cluster, set the KUBECONFIG environment variable as follows:"
	@echo "export KUBECONFIG=$$(realpath "$(KIND_KUBECONFIG)")"
	@echo =======
