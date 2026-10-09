#!/bin/bash
#
# Builds Discord's libdave (DAVE end-to-end voice encryption) with its dependencies
# and packs it into Vendor/CDave.xcframework for the CDave binary target.
#
# Usage: scripts/build-libdave.sh
# Needs: Xcode command line tools, git, python3 (for a local cmake if none is installed).

set -euo pipefail

LIBDAVE_REPO="https://github.com/discord/libdave.git"
LIBDAVE_REV="8de72b1f8a2ac3c5a5270755bb8091a62e3c6169"
DEPLOYMENT_TARGET="13.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# vcpkg and OpenSSL do not build from paths with spaces, so the work tree lives outside the repo.
WORK="${DISCORDKIT_LIBDAVE_WORK:-$HOME/Library/Caches/DiscordKit-libdave}"
SRC="$WORK/libdave"
OUTPUT="$ROOT/Vendor/CDave.xcframework"

case "$WORK" in
    *" "*) echo "Work directory must not contain spaces: $WORK (set DISCORDKIT_LIBDAVE_WORK)" >&2; exit 1 ;;
esac
mkdir -p "$WORK"

if ! command -v cmake >/dev/null 2>&1; then
    if [ ! -x "$WORK/venv/bin/cmake" ]; then
        echo "==> cmake not found, installing a local copy into $WORK/venv"
        python3 -m venv "$WORK/venv"
        "$WORK/venv/bin/pip" install --quiet cmake ninja
    fi
    export PATH="$WORK/venv/bin:$PATH"
fi

if [ ! -d "$SRC/.git" ]; then
    echo "==> Cloning libdave"
    git clone --quiet "$LIBDAVE_REPO" "$SRC"
fi
git -C "$SRC" fetch --quiet origin "$LIBDAVE_REV"
git -C "$SRC" checkout --quiet "$LIBDAVE_REV"
git -C "$SRC" submodule update --init --recursive --quiet

# vcpkg's stock arm64-osx triplet builds for the host macOS version.
TRIPLETS="$WORK/triplets"
mkdir -p "$TRIPLETS"
cat > "$TRIPLETS/arm64-osx-discordkit.cmake" <<TRIPLET
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)
set(VCPKG_OSX_DEPLOYMENT_TARGET $DEPLOYMENT_TARGET)
TRIPLET

cd "$SRC/cpp"
if [ ! -x vcpkg/vcpkg ]; then
    echo "==> Bootstrapping vcpkg"
    ./vcpkg/bootstrap-vcpkg.sh -disableMetrics >/dev/null
fi

echo "==> Building libdave (first run takes several minutes)"
BUILD_DIR="$WORK/build"
{
    cmake -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$SRC/cpp/vcpkg/scripts/buildsystems/vcpkg.cmake" \
        -DVCPKG_MANIFEST_DIR="$SRC/cpp/vcpkg-alts/openssl_3" \
        -DVCPKG_TARGET_TRIPLET=arm64-osx-discordkit \
        -DVCPKG_OVERLAY_TRIPLETS="$TRIPLETS" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DBUILD_SHARED_LIBS=OFF \
        -DTESTING=OFF \
        -DPERSISTENT_KEYS=OFF \
        -DENABLE_SANITIZERS=OFF &&
    cmake --build "$BUILD_DIR" --target libdave --config Release
} >"$WORK/build.log" 2>&1 || {
    echo "libdave build failed, see $WORK/build.log" >&2
    exit 1
}

echo "==> Packing CDave.xcframework"
LIBS="$BUILD_DIR/vcpkg_installed/arm64-osx-discordkit/lib"
STAGE="$WORK/stage"
rm -rf "$STAGE" "$OUTPUT"
mkdir -p "$STAGE/Headers"
libtool -static -no_warning_for_no_symbols -o "$STAGE/libCDave.a" \
    "$BUILD_DIR/libdave.a" \
    "$LIBS/libmlspp.a" "$LIBS/libmls_ds.a" "$LIBS/libtls_syntax.a" \
    "$LIBS/libbytes.a" "$LIBS/libhpke.a" "$LIBS/libssl.a" "$LIBS/libcrypto.a"
cp "$SRC/cpp/includes/dave/dave.h" "$STAGE/Headers/"
cat > "$STAGE/Headers/module.modulemap" <<MODULEMAP
module CDave {
    header "dave.h"
    link "c++"
    export *
}
MODULEMAP

mkdir -p "$ROOT/Vendor"
xcodebuild -create-xcframework -library "$STAGE/libCDave.a" -headers "$STAGE/Headers" -output "$OUTPUT" >/dev/null
echo "==> Done: $OUTPUT"
