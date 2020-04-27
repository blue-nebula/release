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

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
fi

# use RAM disk if possible (e.g., while cross-compiling)
# RAM disk is not available on mac, therefore we use the system default there
if [ ! -z "$TEMP_BASE" ]; then
    BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" relegacy-build-XXXXXX)
else
    BUILD_DIR=$(mktemp -d relegacy-build-XXXXXX)
fi

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

# first, we need to build macdylibbundler
git clone https://github.com/auriamg/macdylibbundler
pushd macdylibbundler

# we have to apply a minor patch: we need to be able to set the otool executable from an env var
git apply <<\EOF
diff --git a/src/DylibBundler.cpp b/src/DylibBundler.cpp
index e7bf46b..6e359bf 100644
--- a/src/DylibBundler.cpp
+++ b/src/DylibBundler.cpp
@@ -71,7 +71,7 @@ void collectRpaths(const std::string& filename)
         return;
     }
 
-    std::string cmd = "otool -l " + filename;
+    std::string cmd = std::string(getenv("OTOOL")) + " -l " + filename;
     std::string output = system_get_output(cmd);
 
     std::vector<std::string> lc_lines;
@@ -199,7 +199,7 @@ void addDependency(std::string path, std::string filename)
 void collectDependencies(std::string filename, std::vector<std::string>& lines)
 {
     // execute "otool -l" on the given file and collect the command's output
-    std::string cmd = "otool -l " + filename;
+    std::string cmd = std::string(getenv("OTOOL")) + " -l " + filename;
     std::string output = system_get_output(cmd);
 
     if(output.find("can't open file")!=std::string::npos or output.find("No such file")!=std::string::npos or output.size()<1)
EOF

make -j7

# it just creates the binary here, so let's just add it to $PATH to be able to access it conveniently
export PATH="$(realpath .):$PATH"

popd

# after having applied that patch above, we need to ensure $OTOOL is set or the whole thing will segfault
export OTOOL="${OTOOL:-otool}"

# now let's build the binaries and install them into the usual FHS-style directory tree
git clone --recursive https://github.com/redeclipse-legacy/base.git

cd base

mkdir build
cd build

# allow overwriting for cross compilation
export CMAKE="${CMAKE:-cmake}"

if type nproc &>/dev/null; then
    procs=$(nproc --ignore=1)
else
    # macos doesn't have nproc, and nprocs does not support ignore
    procs=$(nprocs)
fi

# we do not need any prefix in our zip archive, so we just write /
"$CMAKE" .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/

make preinstall -j"$procs"

# this is the name of the directory we will "install" to, as well as the created zip file's name
DESTDIR=redeclipse-legacy-"$(git describe --tags)"-macos-"$ARCH"

# install everything into a temporary FHS-style tree which we will later zip manually after having collected the deps
make install DESTDIR="$DESTDIR" &>install.log

# now, we can use macdylibbundler to collect the deps
# NOTE: THIS STEP DOES ONLY WORK ON MACOS PROPERLY
# we could also patch the tool more (and provide search paths via -s for the osxcross libs), but it's easier to just run it on macOS
dylibbundler -od -b -x "$DESTDIR"/bin/redeclipse-legacy_osx -d "$DESTDIR"/lib/

# copy the license files from the bundled Windows libs dir... to be on the safe side
cp ../src/bundled-libs/"${ARCH}"-w64-mingw32/lib/LICENSE* "$DESTDIR"/lib/

# let's build the final zip archive
zip -r "$DESTDIR".zip "$DESTDIR"/* &>zip.log

# move the build product back into the filesystem
mv *.zip "$OLD_CWD"
