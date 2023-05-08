import 'dart:ffi';
import 'dart:typed_data';

import 'configuration.dart';

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
    TransportServer server,
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
  late Pointer<sockaddr> _destination;
  final TransportPayloadPool _pool;
  late Uint8List _bytes;
  late TransportServer _server;
  late TransportChannel _channel;

  Uint8List get receivedBytes => _bytes;

  TransportDatagramResponder(this._bufferId, this._pool);

  bool get active => !_server.closing;

  @pragma(preferInlinePragma)
  Future<void> respondSingleMessage(Uint8List bytes, {bool submit = true, int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _server.respondSingleMessage(
          _channel,
          _destination,
          bytes,
          submit: submit,
          flags: flags,
        )
      : retry.options.retry(
          () => _server.respondSingleMessage(
            _channel,
            _destination,
            bytes,
            submit: submit,
            flags: flags,
          ),
          onRetry: retry.onRetry,
          retryIf: retry.predicate,
        );

  @pragma(preferInlinePragma)
  Future<void> respondManyMessage(List<Uint8List> bytes, {bool submit = true, int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _server.respondManyMessages(
          _channel,
          _destination,
          bytes,
          submit: submit,
          flags: flags,
        )
      : retry.options.retry(
          () => _server.respondManyMessages(
            _channel,
            _destination,
            bytes,
            submit: submit,
            flags: flags,
          ),
          onRetry: retry.onRetry,
          retryIf: retry.predicate,
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
