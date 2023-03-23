import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/pool.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';
import 'worker.dart';

class TransportClient {
  final TransportWorkerCallbacks _callbacks;
  final TransportOutboundChannel _channel;

  TransportClient(this._callbacks, this._channel);

  Future<TransportPayload> read() async {
    final completer = Completer<TransportPayload>();
    final bufferId = await _channel.allocate();
    _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, offset: 0);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final completer = Completer<void>();
    final bufferId = await _channel.allocate();
    _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId);
    return completer.future;
  }

  void close() => _channel.close();
}

class TransportConnector {
  final TransportBindings _bindings;
  final TransportWorkerCallbacks _callbacks;
  final Pointer<transport_t> _transportPointer;
  final Pointer<transport_worker_t> _workerPointer;

  TransportConnector(this._callbacks, this._transportPointer, this._workerPointer, this._bindings);

  Future<TransportPool<TransportClient>> connect(String host, int port, {int? pool}) async {
    final clients = <Future<TransportClient>>[];
    if (pool == null) pool = _transportPointer.ref.client_configuration.ref.default_pool;
    for (var clientIndex = 0; clientIndex < pool; clientIndex++) {
      final client = using((arena) => _bindings.transport_client_initialize(
            _transportPointer.ref.client_configuration,
            host.toNativeUtf8(allocator: arena).cast(),
            port,
          ));
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(client.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, client);
      clients.add(completer.future);
    }
    return TransportPool<TransportClient>(await Future.wait(clients));
  }
}
