#!/bin/sh
set -e

on_exit () {
	[ $? -eq 0 ] && exit
	echo 'ERROR: Feature "jq, yq, gojq, xq, jaq" (ghcr.io/eitsupi/devcontainer-features/jq-likes) failed to install! Look at the documentation at https://github.com/eitsupi/devcontainer-features/tree/main/src/jq-likes for help troubleshooting this error.'
}

trap on_exit EXIT

set -a
. ../devcontainer-features.builtin.env
. ./devcontainer-features.env
set +a

echo ===========================================================================

echo 'Feature       : jq, yq, gojq, xq, jaq'
echo 'Description   : Installs jq and jq like command line tools (yq, gojq, xq, jaq).'
echo 'Id            : ghcr.io/eitsupi/devcontainer-features/jq-likes'
echo 'Version       : 2.1.1'
echo 'Documentation : https://github.com/eitsupi/devcontainer-features/tree/main/src/jq-likes'
echo 'Options       :'
echo '    ALLOWJQRCVERSION="false"
    GOJQVERSION="none"
    JAQVERSION="none"
    JQVERSION="latest"
    XQVERSION="none"
    YQVERSION="latest"'
echo ===========================================================================

chmod +x ./install.sh
./install.sh
