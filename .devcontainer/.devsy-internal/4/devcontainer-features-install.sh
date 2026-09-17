#!/bin/sh
set -e

on_exit () {
	[ $? -eq 0 ] && exit
	echo 'ERROR: Feature "Modern shell utils" (ghcr.io/mikaello/devcontainer-features/modern-shell-utils) failed to install!'
}

trap on_exit EXIT

set -a
. ../devcontainer-features.builtin.env
. ./devcontainer-features.env
set +a

echo ===========================================================================

echo 'Feature       : Modern shell utils'
echo 'Description   : A collection of modern shell utils'
echo 'Id            : ghcr.io/mikaello/devcontainer-features/modern-shell-utils'
echo 'Version       : 2.0.0'
echo 'Documentation : '
echo 'Options       :'
echo '    '
echo ===========================================================================

chmod +x ./install.sh
./install.sh
