import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels.dart';
import 'loop.dart';
import 'payload.dart';
import 'transport.dart';

class TransportClient {
  final TransportEventLoopCallbacks _callbacks;
  final TransportOutboundChannel _channel;

  TransportClient(this._callbacks, this._channel);

  Future<TransportPayload> read() async {
    final completer = Completer<TransportPayload>();
    final bufferId = await _channel.allocate();
    final callbackId = await _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, callbackId, offset: 0);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final completer = Completer<void>();
    final bufferId = await _channel.allocate();
    final callbackId = await _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId, callbackId);
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
}

class TransportConnector {
  final TransportBindings _bindings;
  final TransportEventLoopCallbacks _callbacks;
  final Pointer<transport_t> _transportPointer;
  final Transport _transport;

  TransportConnector(this._callbacks, this._transportPointer, this._bindings, this._transport);

  Future<TransportClientPool> connect(String host, int port, {int? pool}) async {
    final clients = <Future<TransportClient>>[];
    if (pool == null) pool = _transport.connectorConfiguration.defaultPool;
    for (var clientIndex = 0; clientIndex < pool; clientIndex++) {
      final connector = using((arena) => _bindings.transport_connector_initialize(
            _transportPointer.ref.connector_configuration,
            host.toNativeUtf8(allocator: arena).cast(),
            port,
          ));
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(connector.ref.fd, completer);
      _bindings.transport_channel_connect(_bindings.transport_channel_pool_next(_transportPointer.ref.channels), connector);
      clients.add(completer.future);
    }
    return TransportClientPool(await Future.wait(clients));
  }
}
