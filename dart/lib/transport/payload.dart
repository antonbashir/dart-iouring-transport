import 'dart:typed_data';

import 'buffers.dart';
import 'constants.dart';

class TransportPayloadPool {
  final TransportBuffers _buffers;
  final _payloads = <TransportPayload>[];

  TransportPayloadPool(int buffersCount, this._buffers) {
    for (var bufferId = 0; bufferId < buffersCount; bufferId++) {
      _payloads.add(TransportPayload(bufferId, this));
    }
  }

  @pragma(preferInlinePragma)
  TransportPayload getPayload(int bufferId, Uint8List bytes) {
    final payload = _payloads[bufferId];
    payload._bytes = bytes;
    return payload;
  }

  @pragma(preferInlinePragma)
  void release(int bufferId) => _buffers.release(bufferId);
}

class TransportPayload {
  late Uint8List _bytes;
  final int _bufferId;
  final TransportPayloadPool _pool;

  Uint8List get bytes => _bytes;

  TransportPayload(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  void release() => _pool.release(_bufferId);

  @pragma(preferInlinePragma)
  Uint8List takeBytes({bool release = true}) {
    final result = Uint8List.fromList(bytes);
    if (release) this.release();
    return result;
  }

  @pragma(preferInlinePragma)
  List<int> toBytes({bool release = true}) {
    final result = _bytes.toList();
    if (release) this.release();
    return result;
  }
}
