import 'package:vector_math/vector_math.dart';

import 'geometry/proc.dart' show D3BillboardProc;
import 'scene_model.dart';
import 'texture_atlas.dart' show TextureAtlas;

/// Compositing for a standalone billboard using [D3SpriteMaterial].
enum D3SpriteBlendMode { alpha, additive }

/// Basic sprite material for one [D3BillboardProc] on its own node.
///
/// The native contract is unlit, double-sided, depth-tested without depth
/// writes, and without casting or receiving shadows. Alpha uses source-over;
/// additive adds alpha-weighted color while preserving destination coverage.
/// Texture, linear tint and billboard vertex color multiply together once.
///
/// [colorTexture] references an existing image or render-texture resource.
/// Author resources before attaching the billboard. The caller owns resource
/// IDs, document insertion, frame selection and same-ID material upserts.
/// Facing, size, rotation and vertex color belong to [D3BillboardProc].
/// Independent frames use distinct material IDs and may share one texture.
/// Per-instance frames, interpolation, soft depth, near fade, late material
/// arrival and independent facing for multiple views are outside this contract.
class D3SpriteMaterial {
  D3SpriteMaterial({
    this.colorTexture,
    Vector4? tint,
    this.blendMode = D3SpriteBlendMode.alpha,
    this.textureRect,
  }) : tint = tint ?? Vector4.all(1);

  final LocalId? colorTexture;

  /// Linear RGBA factor, defaulting to white.
  final Vector4 tint;
  final D3SpriteBlendMode blendMode;

  /// Normalized top-left rectangle as minU, minV, maxU, maxV.
  /// Null samples the full texture. A [TextureAtlas] can supply tile bounds.
  final Vector4? textureRect;

  /// Returns a fresh ordinary material resource with the caller's [id].
  MaterialResource toResource(LocalId id) {
    final rect = textureRect;
    return MaterialResource(
      id,
      type: 'd3:sprite',
      properties: {
        'baseColor': ColorValue(tint.x, tint.y, tint.z, tint.w),
        if (colorTexture != null)
          'baseColorTexture': ResourceRefValue(colorTexture!),
        if (rect != null)
          'baseColorTextureTransform': MapValue({
            'offset': Vec2Value(Vector2(rect.x, rect.y)),
            'scale': Vec2Value(Vector2(rect.z - rect.x, rect.w - rect.y)),
          }),
        'blendMode': StringValue(blendMode.name),
      },
    );
  }
}
