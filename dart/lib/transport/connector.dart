import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:tuple/tuple.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';

class TransportClient {
  final TransportEventLoopCallbacks _callbacks;
  final TransportResourceChannel _channel;
  final Pointer<transport_channel_t> _channelPointer;
  final TransportBindings _bindings;
  final int _fd;
  final int _bufferId;

  TransportClient(this._callbacks, this._channel, this._bindings, this._fd, this._bufferId, this._channelPointer);

  Future<TransportPayload> read() {
    final completer = Completer<TransportPayload>();
    _callbacks.putRead(Tuple2(_channelPointer.address, _bufferId), completer);
    _channel.read(_fd, _bufferId);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) {
    final completer = Completer<void>();
    _callbacks.putWrite(Tuple2(_channelPointer.address, _bufferId), completer);
    _channel.write(bytes, _fd, _bufferId);
    return completer.future;
  }

  void send(Uint8List bytes, {int offset = 0}) => _channel.write(bytes, _fd, _bufferId, offset: offset);

  void close() => _bindings.transport_close_descritor(_fd);
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
