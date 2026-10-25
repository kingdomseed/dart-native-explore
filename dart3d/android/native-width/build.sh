#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work="$here/../build/native-width"
gradle_cmd=${GRADLE:-gradle}
mkdir -p "$work"
if [[ ! -d "$work/jolt-jni/.git" ]]; then
    git clone --branch 6.0.0 --depth 1 https://github.com/stephengold/jolt-jni.git "$work/jolt-jni"
fi
if [[ ! -d "$work/JoltPhysics/.git" ]]; then
    git clone --branch sg260728 --depth 1 https://github.com/stephengold/JoltPhysics.git "$work/JoltPhysics"
fi
test "$(git -C "$work/jolt-jni" rev-parse HEAD)" = 27e7e81b4cba126699878241c247141cd385dc92
test "$(git -C "$work/JoltPhysics" rev-parse HEAD)" = 16960dd9f41d3d13bd87df152a24c17b057ad384
if git -C "$work/JoltPhysics" diff --quiet; then
    git -C "$work/JoltPhysics" apply "$here/jolt-width.patch"
else
    git -C "$work/JoltPhysics" apply --reverse --check "$here/jolt-width.patch"
fi
(
    cd "$work/jolt-jni"
    "$gradle_cmd" -Ptarget=no_natives classes compileTestJava unpackVhacdSource
    echo 'ce3c43193ef28f14003a0e9546829ce0fa140a983222ee4f00dc27ca0ae8ec6d  downloads/v-hacd-4.1.0.zip' | shasum -a 256 -c -
    echo '02314c575909d656dc67d6e3c38cefc49c4403e8ca1dcb0ab4b05800cee61e1c  src/main/native/VHACD.h' | shasum -a 256 -c -
)
if [[ $# == 0 ]]; then
    set -- mac arm64-v8a x86_64
fi
for abi in "$@"; do
    args=()
    if [[ "$abi" == mac ]]; then
        args+=(-DCMAKE_OSX_ARCHITECTURES=arm64)
    else
        ndk="${ANDROID_HOME:?Set ANDROID_HOME}/ndk/28.2.13676358"
        args+=(-DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake"
            -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-26 -DANDROID_STL=c++_static)
    fi
    cmake -S "$here" -B "$work/$abi" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DJOLT_SOURCE="$work/JoltPhysics" -DJNI_SOURCE="$work/jolt-jni" "${args[@]}"
    cmake --build "$work/$abi" -j "${JOBS:-6}"
    if [[ "$abi" != mac ]]; then
        mkdir -p "$here/libs/$abi"
        cp "$work/$abi/libjoltjni.so" "$here/libs/$abi/libjoltjni.so"
        "$ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip" --strip-unneeded "$here/libs/$abi/libjoltjni.so"
    fi
done
