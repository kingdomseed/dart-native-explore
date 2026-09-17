// Generates an uncompressed KTX2 (VK_FORMAT_R8G8B8A8_SRGB, no
// supercompression) from a raw .rgba file so the iOS parseKTX2 path
// can be exercised without BasisU transcoding.
// Usage: dart run tool/make_ktx2.dart <in.rgba> <w> <h> <levels> <out.ktx2>
import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  if (args.length != 5) {
    stderr.writeln('usage: make_ktx2 <in.rgba> <w> <h> <levels> <out>');
    exit(2);
  }
  final rgba = File(args[0]).readAsBytesSync();
  final w = int.parse(args[1]);
  final h = int.parse(args[2]);
  final levels = int.parse(args[3]);
  final out = File(args[4]);

  var expected = 0;
  for (var i = 0; i < levels; i++) {
    expected += (w >> i == 0 ? 1 : w >> i) * (h >> i == 0 ? 1 : h >> i) * 4;
  }
  if (rgba.length != expected) {
    stderr.writeln('rgba ${rgba.length} != expected $expected');
    exit(2);
  }

  // KHR_DFD basic descriptor for RGBSDA/sRGB, four 8-bit samples.
  // descriptorBlock = 24-byte header+model fields + 16B per sample.
  const dfdBlockSize = 24 + 16 * 4;
  const dfdTotal = 4 + dfdBlockSize;
  final dfd = ByteData(dfdTotal);
  dfd.setUint32(0, dfdTotal, Endian.little);
  // vendorId(17) | descriptorType(15): both 0 = KHR_DFD_BASIC
  dfd.setUint32(4, 0, Endian.little);
  dfd.setUint16(8, 2, Endian.little); // versionNumber
  dfd.setUint16(10, dfdBlockSize, Endian.little);
  dfd.setUint8(12, 2); // colorModel = KHR_DF_MODEL_RGBSDA
  dfd.setUint8(13, 1); // colorPrimaries = KHR_DF_PRIMARIES_BT709
  dfd.setUint8(14, 2); // transferFunction = KHR_DF_TRANSFER_SRGB
  dfd.setUint8(15, 0); // flags
  dfd.setUint8(16, 4); // bytesPlane0 = 4 (packed RGBA8)
  for (var s = 0; s < 4; s++) {
    final b = 24 + s * 16;
    dfd.setUint16(b + 0, s * 8, Endian.little); // bitOffset
    dfd.setUint8(b + 2, 7); // bitLength = 8 bits - 1
    dfd.setUint8(b + 3, s == 3 ? 15 : s); // channel R=0 G=1 B=2 A=15
    // samplePosition[4] at b+4..7 stay 0.
    dfd.setFloat32(b + 8, 0.0, Endian.little); // sampleLower
    dfd.setFloat32(b + 12, 1.0, Endian.little); // sampleUpper
  }

  const headerSize = 80;
  final indexSize = levels * 24;
  final dfdOff = headerSize + indexSize;
  final dataOff = dfdOff + dfdTotal;

  final levelOffsets = <int>[];
  final levelLens = <int>[];
  var off = dataOff;
  for (var i = 0; i < levels; i++) {
    final len = (w >> i == 0 ? 1 : w >> i) * (h >> i == 0 ? 1 : h >> i) * 4;
    levelOffsets.add(off);
    levelLens.add(len);
    off += len;
    if (off % 4 != 0) off += 4 - (off % 4);
  }

  final buf = ByteData(off);
  const magic = [
    0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A
  ];
  for (var i = 0; i < 12; i++) {
    buf.setUint8(i, magic[i]);
  }
  buf.setUint32(12, 37, Endian.little); // vkFormat R8G8B8A8_SRGB
  buf.setUint32(16, 4, Endian.little); // typeSize
  buf.setUint32(20, w, Endian.little);
  buf.setUint32(24, h, Endian.little);
  buf.setUint32(28, 0, Endian.little); // pixelDepth
  buf.setUint32(32, 0, Endian.little); // layerCount
  buf.setUint32(36, 1, Endian.little); // faceCount
  buf.setUint32(40, levels, Endian.little);
  buf.setUint32(44, 0, Endian.little); // supercompressionScheme = none
  buf.setUint32(48, dfdOff, Endian.little);
  buf.setUint32(52, dfdTotal, Endian.little);
  buf.setUint32(56, 0, Endian.little); // kvd offset
  buf.setUint32(60, 0, Endian.little); // kvd length
  buf.setUint64(64, 0, Endian.little); // sgd offset
  buf.setUint64(72, 0, Endian.little); // sgd length
  for (var i = 0; i < levels; i++) {
    final b = headerSize + i * 24;
    buf.setUint64(b + 0, levelOffsets[i], Endian.little);
    buf.setUint64(b + 8, levelLens[i], Endian.little);
    buf.setUint64(b + 16, levelLens[i], Endian.little);
  }
  buf.buffer.asUint8List().setRange(dfdOff, dfdOff + dfdTotal, dfd.buffer.asUint8List());

  var cursor = 0;
  for (var i = 0; i < levels; i++) {
    buf.buffer.asUint8List().setRange(
        levelOffsets[i], levelOffsets[i] + levelLens[i], rgba, cursor);
    cursor += levelLens[i];
  }
  out.writeAsBytesSync(buf.buffer.asUint8List());
  stdout.writeln('wrote ${out.path}: $off bytes, ${w}x$h, $levels levels');
}
