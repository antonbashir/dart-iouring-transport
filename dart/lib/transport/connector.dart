import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/model.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';
import 'worker.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
  final TransportOutboundChannel _channel;

  TransportClient(this._callbacks, this._channel);

  Future<TransportOutboundPayload> read() async {
    final bufferId = await _channel.allocate();
    final completer = Completer<TransportOutboundPayload>.sync();
    _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, offset: 0);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = await _channel.allocate();
    final completer = Completer<void>.sync();
    _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId);
    return completer.future;
  }

  void close() => _channel.close();
}

class TransportClientPool {
  final List<TransportClient> _clients;
  var _next = 0;

  TransportClientPool(this._clients);

  TransportClient select() {
    final client = _clients[_next];
    if (++_next == _clients.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportClient object) action) => _clients.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportClient object) mapper) => _clients.map(mapper);
}

class TransportConnector {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_t> _transportPointer;
  final Pointer<transport_worker_t> _workerPointer;

  TransportConnector(this._callbacks, this._transportPointer, this._workerPointer, this._bindings);

  Future<TransportClientPool> connect(TransportUri uri, {int? pool}) async {
    final clients = <Future<TransportClient>>[];
    if (pool == null) pool = _transportPointer.ref.client_configuration.ref.default_pool;
    for (var clientIndex = 0; clientIndex < pool; clientIndex++) {
      final client = using(
        (arena) => _bindings.transport_client_initialize(_transportPointer.ref.client_configuration, uri.host!.toNativeUtf8(allocator: arena).cast(), uri.port!),
      );
      print("connect, fd = ${client.ref.fd}");
      final completer = Completer<TransportClient>.sync();
      _callbacks.putConnect(client.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, client);
      clients.add(completer.future);
    }
    return TransportClientPool(await Future.wait(clients));
  }
}
