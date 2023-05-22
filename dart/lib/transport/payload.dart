import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
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
  TransportDatagramResponder getDatagramResponder(
    int bufferId,
    Uint8List bytes,
    TransportServerChannel server,
    TransportChannel channel,
    Pointer<sockaddr> destination,
  ) {
    final payload = _datagramResponders[bufferId];
    payload._bytes = bytes;
    payload._server = server;
    payload._channel = channel;
    payload._destination = destination;
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

class TransportDatagramResponder {
  final int _bufferId;
  final TransportPayloadPool _pool;

  late Pointer<sockaddr> _destination;
  late Uint8List _bytes;
  late TransportServerChannel _server;
  late TransportChannel _channel;

  Uint8List get receivedBytes => _bytes;
  bool get active => _server.active;

  TransportDatagramResponder(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  void respondSingleMessage(Uint8List bytes, {int? flags, void Function(Exception error)? onError}) => unawaited(
        _server.respondSingleMessage(
          _channel,
          _destination,
          bytes,
          flags: flags,
          onError: onError,
        ),
      );

  @pragma(preferInlinePragma)
  void respondManyMessage(List<Uint8List> bytes, {int? flags, void Function(Exception error)? onError}) => unawaited(
        _server.respondManyMessages(
          _channel,
          _destination,
          bytes,
          flags: flags,
          onError: onError,
        ),
      );

  @pragma(preferInlinePragma)
  void release() => _pool.release(_bufferId);

  @pragma(preferInlinePragma)
  Uint8List takeBytes({bool release = true}) {
    final result = Uint8List.fromList(_bytes);
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
