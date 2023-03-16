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

  TransportClient(this._callbacks, this._channel, this._bindings, this._fd, this._channelPointer);

  Future<TransportPayload> read() => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<TransportPayload>();
          _callbacks.putRead(Tuple2(_channelPointer.address, bufferId), completer);
          _channel.read(_fd, bufferId);
          return completer.future;
        },
      );

  Future<void> write(Uint8List bytes) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<void>();
          _callbacks.putWrite(Tuple2(_channelPointer.address, bufferId), completer);
          _channel.write(bytes, _fd, bufferId);
          return completer.future;
        },
      );

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
    for (var i = 0; i < pool; i++) {
      final completer = Completer<TransportClient>();
      final fd = _bindings.transport_socket_create_client(
        _transport.connectorConfiguration.maxConnections,
        _transport.connectorConfiguration.receiveBufferSize,
        _transport.connectorConfiguration.sendBufferSize,
      );
      _callbacks.putConnect(fd, completer);
      using((arena) => _bindings.transport_channel_connect(_bindings.transport_select_outbound_channel(_transportPointer), fd, host.toNativeUtf8(allocator: arena).cast(), port));
      clients.add(completer.future);
    }
    return TransportClientPool(await Future.wait(clients));
  }
}
