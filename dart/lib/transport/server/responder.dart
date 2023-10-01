import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
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
  void respondSingle(Uint8List bytes, {int? flags, void Function(Exception error)? onError, void Function()? onDone}) {
    unawaited(
      _server
          .respondSingle(
            _channel,
            _destination,
            bytes,
            flags: flags,
            onError: onError,
            onDone: onDone,
          )
          .onError((error, stackTrace) => onError?.call(error as Exception)),
    );
  }

  @pragma(preferInlinePragma)
  void respondMany(List<Uint8List> bytes, {int? flags, bool linked = true, void Function(Exception error)? onError, void Function()? onDone}) {
    var doneCounter = 0;
    var errorCounter = 0;
    unawaited(_server.respondMany(_channel, _destination, bytes, flags: flags, linked: linked, onError: (error) {
      if (++errorCounter + doneCounter == bytes.length) onError?.call(error);
    }, onDone: () {
      if (errorCounter == 0 && ++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
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
