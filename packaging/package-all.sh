#!/bin/bash

if [ $# -ne "2" ]; then
    echo "Usage: `basename $0` version outputdir"
    exit 1
fi

PACKAGING_DIR=$(python -c "import os; print(os.path.dirname(os.path.realpath('$0')))")
TEMPLATE_ROOT="${PACKAGING_DIR}/../"

# shellcheck source=mod.config
. "${TEMPLATE_ROOT}/mod.config"

if [ -f "${TEMPLATE_ROOT}/user.config" ]; then
	# shellcheck source=user.config
	. "${TEMPLATE_ROOT}/user.config"
fi

if [ "${INCLUDE_DEFAULT_MODS}" = "True" ]; then
	echo "Cannot generate installers while INCLUDE_DEFAULT_MODS is enabled."
	exit 1
fi

# Set the working dir to the location of this script
cd "$(dirname $0)"

pushd windows >/dev/null
echo "Building Windows package"
./buildpackage.sh "$1" "$2"
if [ $? -ne 0 ]; then
    echo "Windows package build failed."
fi
popd >/dev/null

pushd osx >/dev/null
echo "Building macOS package"
./buildpackage.sh "$1" "$2"
if [ $? -ne 0 ]; then
    echo "macOS package build failed."
fi
popd >/dev/null

echo "Package build done."
