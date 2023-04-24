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
    return payload;
  }

  @pragma(preferInlinePragma)
  void release(int bufferId) => _buffers.release(bufferId);

  @pragma(preferInlinePragma)
  TransportDatagramResponder getDatagramResponder(int bufferId, Uint8List bytes, TransportServer server, TransportChannel channel) {
    final payload = _datagramResponders[bufferId];
    payload._bytes = bytes;
    payload._server = server;
    payload._channel = channel;
    return payload;
  }
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
    final result = BytesBuilder()..add(_bytes);
    if (release) _pool.release(_bufferId);
    return result.takeBytes();
  }

  @pragma(preferInlinePragma)
  List<int> toBytes({bool release = true}) {
    final result = _bytes.toList();
    if (release) _pool.release(_bufferId);
    return result;
  }
}

class TransportDatagramResponder {
  final int _bufferId;
  final TransportPayloadPool _pool;
  late Uint8List _bytes;
  late TransportServer _server;
  late TransportChannel _channel;

  Uint8List get receivedBytes => _bytes;

  TransportDatagramResponder(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  Future<void> respondSingleMessage(Uint8List bytes, {bool submit = true, int? flags}) => _server.respondSingleMessage(
        _channel,
        _bufferId,
        bytes,
        submit: submit,
        flags: flags,
      );

  @pragma(preferInlinePragma)
  Future<void> respondManyMessage(List<Uint8List> bytes, {bool submit = true, int? flags}) => _server.respondManyMessages(
        _channel,
        _bufferId,
        bytes,
        submit: submit,
        flags: flags,
      );

  @pragma(preferInlinePragma)
  void release() => _pool.release(_bufferId);

  @pragma(preferInlinePragma)
  Uint8List takeBytes({bool release = true}) {
    final result = BytesBuilder()..add(_bytes);
    if (release) _pool.release(_bufferId);
    return result.takeBytes();
  }

  List<int> toBytes({bool release = true}) {
    final result = _bytes.toList();
    if (release) _pool.release(_bufferId);
    return result;
  }
}
