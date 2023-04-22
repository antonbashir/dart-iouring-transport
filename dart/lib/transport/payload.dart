import 'dart:typed_data';

import 'buffers.dart';
import 'channel.dart';
import 'constants.dart';
import 'server/server.dart';

class TransportPayloadPool {
  final TransportBuffers _buffers;
  final _payloads = <TransportPayload>[];
  final _datagramResponders = <TransportDatagramResponder>[];

  TransportPayloadPool(int buffersCount, this._buffers) {
    for (var bufferId = 0; bufferId < buffersCount; bufferId++) {
      _payloads.add(TransportPayload(bufferId, this));
      _datagramResponders.add(TransportDatagramResponder(bufferId, this));
    }
  }

  @pragma(preferInlinePragma)
  TransportPayload getPayload(int bufferId, Uint8List bytes) {
    final payload = _payloads[bufferId];
    payload._bytes = bytes;
    payload._released = false;
    return payload;
  }

  @pragma(preferInlinePragma)
  void releasePayload(int bufferId) {
    _payloads[bufferId]._released = true;
    _buffers.release(bufferId);
  }

  @pragma(preferInlinePragma)
  TransportDatagramResponder getDatagramResponder(int bufferId, Uint8List bytes, TransportServer server, TransportChannel channel) {
    final payload = _datagramResponders[bufferId];
    payload._bytes = bytes;
    payload._released = false;
    payload._server = server;
    payload._channel = channel;
    return payload;
  }

  @pragma(preferInlinePragma)
  void releaseDatagramResponder(int bufferId) {
    _payloads[bufferId]._released = true;
    _buffers.release(bufferId);
  }
}

class TransportPayload {
  late Uint8List _bytes;
  final int _bufferId;
  final TransportPayloadPool _pool;
  var _released = false;

  Uint8List get bytes => _bytes;
  bool get released => _released;

  TransportPayload(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  void release() => _pool.releasePayload(_bufferId);

  @pragma(preferInlinePragma)
  Uint8List extract({bool release = true}) {
    final result = Uint8List.fromList(_bytes.toList());
    if (release) _pool.releasePayload(_bufferId);
    return result;
  }
}

class TransportDatagramResponder {
  final int _bufferId;
  final TransportPayloadPool _pool;
  late Uint8List _bytes;
  late TransportServer _server;
  late TransportChannel _channel;
  var _released = false;

  Uint8List get receivedBytes => _bytes;
  bool get released => _released;

  TransportDatagramResponder(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  Future<void> respondMessage(Uint8List bytes, {int? flags}) => _server.respondMessage(_channel, _bufferId, bytes, flags: flags);

  @pragma(preferInlinePragma)
  Future<void> respondMessageBatch(Iterable<Uint8List> fragments, {int? flags}) => _server.respondMessageBatch(fragments, _channel, _bufferId, flags: flags);

  @pragma(preferInlinePragma)
  void release() => _pool.releaseDatagramResponder(_bufferId);

  List<int> extract({bool release = true}) {
    final result = _bytes.toList();
    if (release) _server.releaseBuffer(_bufferId);
    return result;
  }
}
