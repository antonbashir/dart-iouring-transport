import 'dart:typed_data';

class TransportChunk {
  final int bufferId;
  final Uint8List bytes;

  TransportChunk(this.bufferId, this.bytes);
}
