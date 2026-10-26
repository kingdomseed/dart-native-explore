# Build the stair-width extension

Run `build.sh` on macOS ARM64 with CMake, Ninja, a JDK, Gradle 9.3.1, and Android NDK 28.2.13676358 installed. Set `GRADLE` to the Gradle executable and `ANDROID_HOME` to the Android SDK directory. No SDK files or published artifacts are patched.

```sh
GRADLE=/path/to/gradle-9.3.1/bin/gradle \
ANDROID_HOME=/path/to/Android/sdk \
./dart3d/android/native-width/build.sh
```

The default build produces MacARM, arm64-v8a, and x86_64 libraries. To rebuild one target, pass `mac`, `arm64-v8a`, or `x86_64`. `JOBS` controls compilation parallelism and defaults to 6.

The script retains source checkouts, generated JNI headers, unstripped libraries, and intermediate objects in `android/build/native-width`. It copies stripped Android libraries into `native-width/libs`. Keep these packaged outputs with the source patch. The Android module packages them through `jniLibs` and uses the generated `jolt-jni-Windows64-6.0.0.jar` for the Java API.

Build the pinned Java API JAR separately. This applies `jolt-jni-lifecycle.patch` to Jolt JNI 6.0.0 and builds with native compilation disabled. It replaces the Maven API artifact, so the Android build does not package duplicate classes. The Mac and Android native-width libraries are not rebuilt.

```sh
GRADLE=/path/to/gradle-9.3.1/bin/gradle \
./dart3d/android/native-width/build-jolt-jni-api.sh
```

Run the production Kotlin native regressions from `dart3d/example/android` after resolving the example dependencies and setting its local SDK properties.

```sh
FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com \
/path/to/gradle-9.3.1/bin/gradle \
  --init-script ../../android/native-width/native-tests.init.gradle \
  :dart3d:testReleaseUnitTest --tests '*CharacterControllerNativeTest'
```

Omit `--tests` to run the whole native unit task. The init script enables the existing native-test property, selects the patched MacARM library, and registers that library as a test input. An old library cannot satisfy the new JNI entry point.

## Vendor pins and build flags

- Jolt JNI 6.0.0, commit `27e7e81b4cba126699878241c247141cd385dc92`, from https://github.com/stephengold/jolt-jni.
- Jolt Physics tag `sg260728`, commit `16960dd9f41d3d13bd87df152a24c17b057ad384`, from https://github.com/stephengold/JoltPhysics. This is the tag selected by JNI 6.0.0's `gradle.properties`.
- V-HACD 4.1.0 is unchanged and fetched by the vendor's Gradle task. The script verifies the archive and generated header SHA-256 values.
- C++17, Release `-O3`, single-precision positions, `JPH_NO_DEBUG`, `JPH_OBJECT_STREAM`, `JPH_USE_CPU_COMPUTE`, `JPH_CROSS_PLATFORM_DETERMINISTIC`, and `-fno-rtti`. These match the vendor's SpRelease feature defines. No GPU compute or debug renderer is enabled.
- Android API 26, static libc++, NDK 28.2.13676358, and 16 KB ELF segment alignment. Both shipped Android ABIs are built from the same patched source as the MacARM test library.

The CMake recipe compiles vendor Jolt and JNI glue with only `JoltStairWidth.cpp` added to the native sources. The Java API change is separate. `LICENSE-jolt-jni` accompanies the source patch and generated API JAR.

## Width acceptance

The installed flutter_scene 0.23.0 codec calls `autostepMinWidth` the minimum landing width. flutter_scene_rapier 0.5.1 maps it to Rapier 0.32.0's absolute `CharacterAutostep.min_width`, documented as the minimum free space available after stepping. It is a clearance requirement, not additional requested movement.

`JoltWorld` stores the existing width on its native character through one internal JNI setter. `jolt-width.patch` checks that width inside `CharacterVirtual::WalkStairs`, after Jolt computes `final_position` and before `MoveToContact` commits it. The probe uses the existing padded character sweep, collision filters, character collisions, and contact validation. Its origin is the actual landing, including upward clipping by ceilings.

Only this clearance probe ignores walkable contact surfaces. A rounded stair edge can be part of the accepted supporting surface; treating it as a wall rejects valid stairs. Non-walkable walls and ceilings remain obstacles. Filtering is per hit rather than per body, so another surface on the supporting body remains eligible to block clearance.

The probe neither moves the character nor applies body impulses. A rejected stair leaves ordinary movement intact. Jolt continues to own movement, clipping, contacts, and the candidate pose. All users of the modified C++ class are rebuilt together; the extension must not be linked against an unpatched vendor native library.
