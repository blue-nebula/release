#! /bin/bash

set -e
set -x

if [ "$ARCH" == "" ]; then
    ARCH=$(uname -m)
    echo "Warning: \$ARCH unset, guessing as $ARCH"
fi

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

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" relegacy-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname "$0")))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

git clone --recursive https://github.com/redeclipse-legacy/base.git

cd base

mkdir build
cd build

cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr

make -j"$NPROC"

make install DESTDIR=AppDir &>install.log

wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage

chmod +x linuxdeploy*.AppImage

# configure AppImageUpdate
export UPD_INFO="gh-releases-zsync|redeclipse-legacy|release|continuous|Red_Eclipse_Legacy-*$ARCH.AppImage.zsync"
export VERSION=$(git describe --tags)
./linuxdeploy-"$ARCH".AppImage --appdir AppDir --output appimage

mv Red_Eclipse_Legacy*.AppImage* "$OLD_CWD"
