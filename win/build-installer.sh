#! /bin/bash

set -euxo pipefail

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

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

# save one processor core if possible for other stuff on dev machines
if [ "$CI" == "" ]; then
    NPROC=$(nproc --ignore=1)
else
    NPROC=$(nproc)
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" blue-nebula-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
OLD_CWD="$(readlink -f .)"

pushd "$BUILD_DIR"

git clone --recursive https://github.com/blue-nebula/base.git

cd base

mkdir build
cd build

cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../ci/"$ARCH"-w64-mingw32.cmake

make preinstall -j"$NPROC"

cpack -G NSIS || cat _CPack_Packages/win64/NSIS/NSISOutput.log

mv ./blue-nebula*win64.exe "$OLD_CWD"
