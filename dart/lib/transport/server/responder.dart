import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../configuration.dart';
import '../constants.dart';
import 'server.dart';

class TransportServerDatagramResponderPool {
  final TransportBuffers _buffers;
  final _datagramResponders = <TransportServerDatagramResponder>[];

  TransportServerDatagramResponderPool(int buffersCount, this._buffers) {
    for (var bufferId = 0; bufferId < buffersCount; bufferId++) {
      _datagramResponders.add(TransportServerDatagramResponder(bufferId, this));
    }
  }

  @pragma(preferInlinePragma)
  void release(int bufferId) => _buffers.release(bufferId);

  @pragma(preferInlinePragma)
  TransportServerDatagramResponder getDatagramResponder(
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

class TransportServerDatagramResponder {
  final int _bufferId;
  final TransportServerDatagramResponderPool _pool;

  late Pointer<sockaddr> _destination;
  late Uint8List _bytes;
  late TransportServerChannel _server;
  late TransportChannel _channel;

  Uint8List get receivedBytes => _bytes;
  bool get active => _server.active;

  TransportServerDatagramResponder(this._bufferId, this._pool);

  @pragma(preferInlinePragma)
  void respond(Uint8List bytes, {int? flags, TransportRetryConfiguration? retry, void Function(Exception error)? onError, void Function()? onDone}) {
    if (retry == null) {
      unawaited(
        _server
            .respond(
              _channel,
              _destination,
              bytes,
              flags: flags,
              onError: onError,
              onDone: onDone,
            )
            .onError((error, stackTrace) => onError?.call(error as Exception)),
      );
      return;
    }
    var attempt = 0;
    void _onError(Exception error) {
      if (!retry.predicate(error)) {
        onError?.call(error);
        return;
      }
      if (++attempt == retry.maxAttempts) {
        onError?.call(error);
        return;
      }
      unawaited(Future.delayed(retry.options.delay(attempt), () {
        unawaited(
          _server
              .respond(
                _channel,
                _destination,
                bytes,
                flags: flags,
                onError: _onError,
                onDone: onDone,
              )
              .onError((error, stackTrace) => onError?.call(error as Exception)),
        );
      }));
    }

    unawaited(
      _server
          .respond(
            _channel,
            _destination,
            bytes,
            flags: flags,
            onError: _onError,
            onDone: onDone,
          )
          .onError((error, stackTrace) => onError?.call(error as Exception)),
    );
  }

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
