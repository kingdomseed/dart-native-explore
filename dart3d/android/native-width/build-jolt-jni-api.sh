#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
work="$here/../build/native-width/jolt-jni-api"
source="$work/source"
gradle_cmd=${GRADLE:-gradle}
patch="$here/jolt-jni-lifecycle.patch"
source_file=src/main/java/com/github/stephengold/joltjni/CharacterVsCharacterCollisionSimple.java

mkdir -p "$work"
if [[ ! -d "$source/.git" ]]; then
    git clone --branch 6.0.0 --depth 1 \
        https://github.com/stephengold/jolt-jni.git "$source"
fi
test "$(git -C "$source" rev-parse HEAD)" = \
    27e7e81b4cba126699878241c247141cd385dc92
git -C "$source" diff --cached --quiet
if git -C "$source" diff --quiet; then
    git -C "$source" apply --check "$patch"
    git -C "$source" apply "$patch"
else
    git -C "$source" apply --reverse --check "$patch"
    git -C "$source" diff --binary -- "$source_file" | cmp -s - "$patch"
    git -C "$source" diff --quiet -- . \
        ":(exclude)$source_file"
fi

(
    cd "$source"
    GRADLE_USER_HOME="$work/gradle-home" "$gradle_cmd" --no-daemon \
        -Ptarget=no_natives -Partifact=jolt-jni-Windows64 \
        -PjjVersion=6.0.0 jar
)
jar="$source/build/libs/jolt-jni-Windows64-6.0.0.jar"
test -f "$jar"
cp "$jar" "$here/jolt-jni-Windows64-6.0.0.jar"
