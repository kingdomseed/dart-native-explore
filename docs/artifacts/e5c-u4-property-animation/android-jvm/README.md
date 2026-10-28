# Android U4 Release JVM verification

On 2026-10-27, the actual Gradle Release task ran all eight current
`U4PropertyAnimationTest` cases: zero failures, errors, or skips. The task
executed rather than returning up-to-date. See [JUnit XML](TEST-com.jasonholtdigital.dart3d.U4PropertyAnimationTest.xml)
and [successful transcript](isolated-release-test.log).

The initial attempt failed in `:dart3d:generateReleaseUnitTestStubRFile`:
“The contents of the immutable workspace … have been modified.” The
[original transcript](direct-release-test.log) is retained. No shared cache
was deleted or repaired.

The successful retry used the existing Gradle 9.3.1 distribution and host
JDK 25.0.5.0.2. A private Gradle home received cloned copies of only
`modules-2/files-2.1`, `metadata-2.107`, and `resources-2.1`. Shared transforms,
lock files, `gc.properties`, credentials, and Gradle configuration were not
copied. The project cache was private too. Gradle documents dependency-cache
copying in its [cache guide](https://docs.gradle.org/current/userguide/dependency_caching.html#sec:cache_copy).

From `dart3d/example/android` in the parent writer:

```sh
FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com \
  /Users/jasonholt/.gradle/wrapper/dists/gradle-9.3.1-all/9ot9r568e8zfvvd4mn8rbu1j0/gradle-9.3.1/bin/gradle \
  --gradle-user-home /private/tmp/dart3d-u4-android-jvm-check-20261027/r1/gradle-home \
  --project-cache-dir /private/tmp/dart3d-u4-android-jvm-check-20261027/r1/project-cache \
  --no-daemon --max-workers=2 \
  '-Dorg.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=1g' \
  -Pkotlin.compiler.execution.strategy=in-process \
  :dart3d:testReleaseUnitTest --tests '*U4PropertyAnimationTest'
```

These tests exercise the production metadata decoder, curve validation and
sampling, blending/restoration, retained camera FOV, and light-unit conversion.
They do not execute native Filament handles or prove rendered Android behavior.
Device, GPU, performance, full T2, and whole-U4 acceptance remain **NOT_RUN**
for this verification.

[Source identities](source-sha256.txt) identify the six relevant Kotlin files.
The before/after receipts verify all 58 accepted source paths and six
lock/registrant paths unchanged. No production source was edited. No devices
were queried or used. The private cache and ignored build outputs remain for
later authorized checks; the single-use Gradle daemon exits after the build.
