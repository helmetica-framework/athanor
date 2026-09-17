#!/bin/sh
set -e

on_exit () {
	[ $? -eq 0 ] && exit
	echo 'ERROR: Feature "Nix Package Manager" (ghcr.io/devcontainers/features/nix) failed to install! Look at the documentation at https://github.com/devcontainers/features/tree/main/src/nix for help troubleshooting this error.'
}

trap on_exit EXIT

set -a
. ../devcontainer-features.builtin.env
. ./devcontainer-features.env
set +a

echo ===========================================================================

echo 'Feature       : Nix Package Manager'
echo 'Description   : Installs the Nix package manager and optionally a set of packages.'
echo 'Id            : ghcr.io/devcontainers/features/nix'
echo 'Version       : 1.3.1'
echo 'Documentation : https://github.com/devcontainers/features/tree/main/src/nix'
echo 'Options       :'
echo '    EXTRANIXCONFIG=""
    FLAKEURI=""
    MULTIUSER="true"
    PACKAGES=""
    USEATTRIBUTEPATH="false"
    VERSION="latest"'
echo ===========================================================================

chmod +x ./install.sh
./install.sh
