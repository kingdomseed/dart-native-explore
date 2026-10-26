# Native stair-width extension handoff

Implemented and tested. No remaining build blocker. This closes the focused Android width repro at native unit-test level. It does not declare E4 ready or replace the parent's review and device gates.

## Import

The worktree starts at `6366c07ad805fc97baf785449a9b38c111cbf1e4`. Its baseline imports `tracked.patch`, `untracked.tgz`, `compile-only.patch`, and `android-six-fix.patch`, then uses the supplied `JoltWorld.current.kt` and `CharacterControllerNativeTest.current.kt` replacements. Baseline copies are in `native-width-baseline` beside this report, with hashes in `native-width-manifest.json`.

From a repository root matching that imported baseline, apply `native-width-extension.patch`, then unpack `native-width-extension-binaries.tgz`. The patch includes all added text files and executable mode for `build.sh`. The archive contains both Android libraries and the matching MacARM test library. `native-width-files.sha256` checks every resulting owned file. I performed this import into a baseline copy and verified all 18 paths. See `native-width-import-check.log`.

The delta changes only Android E4 native integration, its build recipe, and tests. It contains no inherited Dart, Swift, showcase, Dart3dView, or program-document changes.

## Implementation

`JoltWorld.kt` adds one call after native character construction. It passes the existing `CharacterSpec.autostepMinWidth` to the internal `JoltStairWidth` JNI setter. Kotlin retains configuration ownership. No Dart or wire API changes were made.

A focused source patch adds one width value to `CharacterVirtual`. `WalkStairs` queries forward clearance from its actual `final_position`, after Jolt's upward clipping and landing computation and before `MoveToContact`. It uses Jolt's padded shape sweep, filters, character-collision path, and contact validation. It does not move the character, replay an update, or apply impulses.

The width-only query ignores walkable surface hits. The first prototype rejected valid stairs because a rounded supporting edge counted as a wall. The retained query ignores that support per hit, while still checking non-walkable surfaces on the same body. Its baseline sweeps and movement solver keep their existing behavior.

The Fix Root Causes principle led to acceptance at the computed landing rather than estimating a pose in Kotlin. Model the Domain led to one native character setting sourced from the existing CharacterSpec, without a callback registry or new API hierarchy.

The five inherited fixes remain in the supplied Kotlin implementation. The patch does not alter their paths. Their regressions pass with the rebuilt library.

## Vendor and outputs

- Jolt JNI 6.0.0 is pinned to `27e7e81b4cba126699878241c247141cd385dc92`.
- Its selected Jolt Physics tag `sg260728` is pinned to `16960dd9f41d3d13bd87df152a24c17b057ad384`.
- V-HACD stays at 4.1.0 with archive and header hash verification.
- Java remains the existing 6.0.0 API jar. The upstream Android natives AAR is replaced by the local patched libraries, so it cannot introduce a duplicate libjoltjni.so.
- All native code sharing the modified class layout is rebuilt together. There are no guessed offsets, binary patches, or old/new C++ object-layout mixtures.
- `android/native-width/README.md` and `build.sh` retain the source pins, flags, licenses, build commands, and test invocation. The script completed, then a second invocation verified all three targets were up to date.

| Output | Bytes | Architecture |
| --- | ---: | --- |
| Packaged libjoltjni.so | 4,565,584 | arm64-v8a |
| Packaged libjoltjni.so | 4,643,840 | x86_64 |
| Matching libjoltjni.dylib | 3,536,496 | MacARM |
| Release example APK | 122,571,010 | arm64-v8a and x86_64 |

Both Android libraries have 16 KB ELF load alignment. Each retains all 3,421 upstream JNI symbols and adds only `Java_com_jasonholtdigital_dart3d_JoltStairWidth_setMinimumWidth`. See the ELF receipts and `native-width-jni-exports.txt`. Hashes and tool versions are in `native-width-manifest.json`.

## Verification

- Original 10-test baseline reproduced one failure and zero skips. `native-width-before.xml` contains `climbed with less than 0.1m of clearance [0.099999905, 0.6694428, -9.9341E-8]`.
- The expanded 14-test suite against the original library produced three failures and zero skips. They cover the narrow landing, the same failure under a ceiling that clips the upward sweep, and preserved ordinary progress when a stair must be rejected. See `native-width-expanded-before.xml` and its log.
- The patched library passes all 14 native controller tests with zero skips. See `native-width-after.xml`.
- The standard `:dart3d:testReleaseUnitTest` task passes all 150 tests across 18 suites with zero failures, errors, or skips. See `native-width-all-final.log` and `native-width-all-xml`.
- Wide-landing and smaller-width positive tests still climb above y=0.65 and remain within dx=0.1001. Narrow-landing tests stay below y=0.6. Both wide and narrow cases run under low overhead. A rejected width preserves ordinary position and applies the same ground-weight impulse as movement with stairs disabled.
- `dn build apk --release --target-platform android-arm64,android-x64 --no-pub` succeeded. The APK contains exactly the two requested Jolt libraries, each byte-identical to the exported library. R8 retains the native setter and class name. See `native-width-release-apk.log` and `native-width-apk-receipt.txt`.
- Applying the delta and extracting the binary archive into a baseline copy reproduced all 18 file hashes, including the executable build script.

## Boundaries and retained files

Physical Android verification, iOS work, independent review, and landing are NOT_RUN and remain parent-owned. No device actions, subdelegation, commits, pushes, PRs, external mutations, or parent-checkout writes occurred.

The first candidate-sweep prototype was replaced after its positive controls failed. Its log and XML are retained as diagnostic evidence, not as passing results. No production test was skipped, ignored, or weakened.

The explicit native-extension authorization was used. The only additions beyond the setter and source patch are its reproducible native build, packaging, licenses, and focused test controls. There was no unrelated library upgrade or feature expansion.

Build caches and generated native outputs remain under this isolated worktree's ignored build directories. The generated `dart3d/example/dn_plugins.lock` remains in the worktree and is excluded from the Android-only delta. Temporary SDK properties and probe scripts are removed after verification. The parent may use the retained APK path from the manifest for its own device work.
