#!/bin/sh
set -e

on_exit () {
	[ $? -eq 0 ] && exit
	echo 'ERROR: Feature "Kubectl, Helm, and Minikube" (ghcr.io/devcontainers/features/kubectl-helm-minikube) failed to install! Look at the documentation at https://github.com/devcontainers/features/tree/main/src/kubectl-helm-minikube for help troubleshooting this error.'
}

trap on_exit EXIT

set -a
. ../devcontainer-features.builtin.env
. ./devcontainer-features.env
set +a

echo ===========================================================================

echo 'Feature       : Kubectl, Helm, and Minikube'
echo 'Description   : Installs latest version of kubectl, Helm, and optionally minikube. Auto-detects latest versions and installs needed dependencies.'
echo 'Id            : ghcr.io/devcontainers/features/kubectl-helm-minikube'
echo 'Version       : 1.3.1'
echo 'Documentation : https://github.com/devcontainers/features/tree/main/src/kubectl-helm-minikube'
echo 'Options       :'
echo '    HELM="latest"
    KUBECTLFALLBACKVERSION="v1.35.1"
    MINIKUBE="none"
    VERSION="latest"'
echo ===========================================================================

chmod +x ./install.sh
./install.sh
