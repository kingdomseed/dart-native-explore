/// dart3d's `.cube` LUT asset-resolution path (W25).
///
/// Upstream keeps `colorGrading.lut` an `AssetRef` — a source-path
/// key like `assets/luts/warm.cube` the host resolves at load time.
/// dart3d resolves the key into a payload chunk: [resolveLutAssets]
/// registers each `.cube` as a `PayloadEncoding.bytes` payload and
/// rewrites the ref to its `chunk:` token, so the wire form the
/// natives consume is a payload id they already defer on — a LUT
/// chunk landing after the stage decode applies on arrival.
///
/// Keys already carrying a chunk token pass through untouched, and
/// resolver misses leave the path string alone — the natives then
/// try their bundle-asset fallback (`AssetManager` on Android, the
/// main bundle on iOS), the same lookup the `asset` environment
/// type uses.
library;

import 'dart:typed_data';

import 'scene_model.dart';

/// Maps an asset-path LUT key (`colorGrading.lut` — e.g.
/// `assets/luts/warm.cube`) to its `.cube` bytes, or null on a miss.
/// Mirrors `PrefabResolver`'s contract: host asset resolution stays
/// on the host layer.
typedef LutResolver = Uint8List? Function(String key);

/// The async form of [LutResolver] — for bundle loaders like
/// `rootBundle.load` that return a `Future`.
typedef AsyncLutResolver = Future<Uint8List?> Function(String key);

/// The wire form a resolved LUT ref takes — `chunk:<token>`, the
/// readability prefix `upsertPayload` ops already carry. Both
/// natives strip the prefix when parsing, so any `x:`-prefixed token
/// resolves the same way.
String lutChunkKey(LocalId id) => 'chunk:${id.toToken()}';

/// Whether [key] already names a payload chunk rather than an asset
/// path — `LocalId.parse` accepts the `x:` readability prefix, so
/// `chunk:…`, `id:…`, and bare tokens all count. Asset paths contain
/// characters outside Crockford base32 and never parse.
bool isLutChunkRef(String key) {
  try {
    LocalId.parse(key);
    return true;
  } on FormatException {
    return false;
  }
}

/// Resolves every environment resource's `effects.colorGradingLut`
/// through [resolve], registering each `.cube` as a `bytes` payload
/// in [doc] and rewriting the ref to its `chunk:` token. Returns
/// the number of refs resolved.
///
/// Mutates [doc]: the payload lands in `doc.payloads` (so
/// `SceneController.loadDocument` ships it with the manifest's other
/// chunks) and the spec's `colorGradingLut` becomes
/// `AssetRef('chunk:<token>')` — upstream's documented seam, since
/// the AssetRef key is the stable string the wire carries verbatim.
/// Refs that already name a chunk skip; resolver misses leave the
/// path string for the native bundle-asset fallback.
int resolveLutAssets(SceneDocument doc, {required LutResolver resolve}) {
  var resolved = 0;
  for (final resource in doc.resources.values) {
    if (resource is! EnvironmentResource) continue;
    final lut = resource.effects.colorGradingLut;
    if (lut == null || isLutChunkRef(lut.key)) continue;
    final bytes = resolve(lut.key);
    if (bytes == null) continue;
    final id = doc.newId();
    doc.addPayload(
      PayloadSpec(
        id,
        encoding: PayloadEncoding.bytes,
        length: bytes.lengthInBytes,
        bytes: bytes,
      ),
    );
    resource.effects.colorGradingLut = AssetRef(lutChunkKey(id));
    resolved++;
  }
  return resolved;
}

/// The async form of [resolveLutAssets] — resolves the refs in
/// declaration order so a deterministic document keeps its minted
/// payload ids stable across runs.
Future<int> resolveLutAssetsAsync(
  SceneDocument doc, {
  required AsyncLutResolver resolve,
}) async {
  var resolved = 0;
  for (final resource in doc.resources.values) {
    if (resource is! EnvironmentResource) continue;
    final lut = resource.effects.colorGradingLut;
    if (lut == null || isLutChunkRef(lut.key)) continue;
    final bytes = await resolve(lut.key);
    if (bytes == null) continue;
    final id = doc.newId();
    doc.addPayload(
      PayloadSpec(
        id,
        encoding: PayloadEncoding.bytes,
        length: bytes.lengthInBytes,
        bytes: bytes,
      ),
    );
    resource.effects.colorGradingLut = AssetRef(lutChunkKey(id));
    resolved++;
  }
  return resolved;
}
