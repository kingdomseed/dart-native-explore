import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

/// A uniform grid texture atlas: one or more equally sized PBR maps packed as
/// `columns` x `rows` square tiles, with an optional gutter of [padding] texels
/// around each tile so mip sampling does not bleed across tile edges.
///
/// The atlas does the UV bookkeeping for tiled content (voxel block faces,
/// sprite sheets, terrain tiles). Resolve a tile's atlas-space UV box with
/// [tileBounds], or map a within-tile coordinate with [tileUv]; a mesh writes
/// those UVs into its texture coordinates so a single material and draw call
/// covers every tile.
///
/// Maps follow the glTF metallic-roughness convention ([baseColor],
/// [metallicRoughness] with metallic in B and roughness in G, [normal],
/// [occlusion]); [toMaterial] wires them into a [MaterialResource].
///
/// The maps are references to caller-owned texture resources in the same scene
/// document. This utility does not allocate ids, insert resources, or upload
/// pixels.
class TextureAtlas {
  /// Creates an atlas of [columns] x [rows] tiles, each [tileSize] texels
  /// square, separated by [padding] texels of gutter. The PBR maps are
  /// optional so the UV math can be used (and unit tested) on its own.
  TextureAtlas({
    required this.columns,
    required this.rows,
    required this.tileSize,
    this.padding = 0,
    this.baseColor,
    this.metallicRoughness,
    this.normal,
    this.occlusion,
  }) : assert(columns > 0),
       assert(rows > 0),
       assert(tileSize > 0),
       assert(padding >= 0);

  /// Tile grid dimensions.
  final int columns;
  final int rows;

  /// Edge length of a tile's content area, in texels.
  final int tileSize;

  /// Gutter of (typically edge-replicated) texels around each tile, in texels.
  final int padding;

  /// Packed PBR texture resource ids, all sharing the same grid layout.
  final LocalId? baseColor;
  final LocalId? metallicRoughness;
  final LocalId? normal;
  final LocalId? occlusion;

  /// Total number of tiles.
  int get tileCount => columns * rows;

  int get _cellSize => tileSize + 2 * padding;

  /// Atlas dimensions in texels (including the padding gutters).
  int get width => columns * _cellSize;
  int get height => rows * _cellSize;

  /// The atlas-space UV box of tile [index]'s content area as
  /// `(minU, minV, maxU, maxV)`, inset past the padding gutter so sampling
  /// stays inside the tile. Tiles are row-major with a top-left origin.
  Vector4 tileBounds(int index) {
    assert(index >= 0 && index < tileCount);
    final col = index % columns;
    final row = index ~/ columns;
    final x0 = col * _cellSize + padding;
    final y0 = row * _cellSize + padding;
    final w = width.toDouble();
    final h = height.toDouble();
    return Vector4(x0 / w, y0 / h, (x0 + tileSize) / w, (y0 + tileSize) / h);
  }

  /// Maps a within-tile coordinate ([u], [v], each in `[0, 1]` with (0, 0) at
  /// the tile's top-left) to an atlas UV for tile [index].
  Vector2 tileUv(int index, double u, double v) {
    final bounds = tileBounds(index);
    return Vector2(
      bounds.x + (bounds.z - bounds.x) * u,
      bounds.y + (bounds.w - bounds.y) * v,
    );
  }

  /// Builds a physically based material with the caller's [id].
  ///
  /// Metallic and roughness factors are explicitly one to preserve upstream's
  /// identity defaults. The caller owns insertion and any later material upsert,
  /// and can customize alpha mode, UV transforms, or other properties on the
  /// returned resource.
  MaterialResource toMaterial(LocalId id) {
    return MaterialResource(
      id,
      type: 'physicallyBased',
      properties: {
        'metallic': const DoubleValue(1.0),
        'roughness': const DoubleValue(1.0),
        if (baseColor != null) 'baseColorTexture': ResourceRefValue(baseColor!),
        if (metallicRoughness != null)
          'metallicRoughnessTexture': ResourceRefValue(metallicRoughness!),
        if (normal != null) 'normalTexture': ResourceRefValue(normal!),
        if (occlusion != null) 'occlusionTexture': ResourceRefValue(occlusion!),
      },
    );
  }
}

/// Builds RGBA8888 pixels (row-major, top-left origin) for a placeholder grid
/// atlas laid out to match a [TextureAtlas] with the same [columns], [tileSize],
/// and [padding]. Each tile's whole cell (content plus padding gutter) is filled
/// with its solid color from [tileColors] (`(r, g, b, a)` in `[0, 1]`), so a
/// tile never bleeds into its neighbor. Cells past `tileColors.length` are left
/// transparent.
///
/// The caller can supply these bytes in an `rgba8` image payload and reference
/// it from a texture resource. No texture is created or uploaded here.
Uint8List generateSolidColorAtlasPixels({
  required List<Vector4> tileColors,
  required int columns,
  required int tileSize,
  int padding = 0,
}) {
  assert(columns > 0);
  assert(tileSize > 0);
  assert(padding >= 0);
  final rows = (tileColors.length / columns).ceil();
  final cell = tileSize + 2 * padding;
  final width = columns * cell;
  final height = rows * cell;
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < tileColors.length; i++) {
    final color = tileColors[i];
    final r = (color.x * 255.0).round().clamp(0, 255);
    final g = (color.y * 255.0).round().clamp(0, 255);
    final b = (color.z * 255.0).round().clamp(0, 255);
    final a = (color.w * 255.0).round().clamp(0, 255);
    final x0 = (i % columns) * cell;
    final y0 = (i ~/ columns) * cell;
    for (var y = y0; y < y0 + cell; y++) {
      var p = (y * width + x0) * 4;
      for (var x = 0; x < cell; x++) {
        pixels[p++] = r;
        pixels[p++] = g;
        pixels[p++] = b;
        pixels[p++] = a;
      }
    }
  }
  return pixels;
}
