#! /bin/bash

set -e
set -x

case "$ARCH" in
    x86_64|amd64|win64)
        export ARCH="x86_64"
        ;;
    i386|i586|i686|win32)
        export ARCH="i686"
        ;;
    *)
        echo "Error: \$ARCH unset, please export ARCH=... (e.g., i686, x86_64)"
        exit 1
        ;;
esac

# RAM disk is not available on mac, therefore we simply use a temporary directory
BUILD_DIR=$(mktemp -d relegacy-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(realpath $(dirname $(dirname "$0")))
OLD_CWD=$(realpath .)

pushd "$BUILD_DIR"

git clone --recursive https://github.com/redeclipse-legacy/base.git

cd base

mkdir build
cd build

cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++

make preinstall -j$(nprocs)

cpack -G ZIP -V

mv *.zip "$OLD_CWD"
