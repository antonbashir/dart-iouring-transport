import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:tuple/tuple.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';

class TransportClient {
  final TransportEventLoopCallbacks _callbacks;
  final TransportResourceChannel _channel;
  final TransportBindings _bindings;
  final int fd;

  TransportClient(this._callbacks, this._channel, this._bindings, this.fd);

  Future<TransportPayload> read() => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<TransportPayload>();
          _callbacks.putRead(Tuple2(_channel.pointer.address, bufferId), completer);
          _channel.read(fd, bufferId);
          return completer.future;
        },
      );

  Future<void> write(Uint8List bytes) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<void>();
          _callbacks.putWrite(Tuple2(_channel.pointer.address, bufferId), completer);
          _channel.write(bytes, fd, bufferId);
          return completer.future;
        },
      );

  void close() => _bindings.transport_close_descritor(fd);
}

class TransportConnector {
  final TransportBindings _bindings;
  final TransportEventLoopCallbacks _callbacks;
  final Pointer<transport_channel_t> _channelPointer;
  final Pointer<transport_t> _transport;

  TransportConnector(this._callbacks, this._channelPointer, this._transport, this._bindings);

  Future<TransportClient> connect(String host, int port) {
    final completer = Completer<TransportClient>();
    final fd = _bindings.transport_socket_create_client(
      _transport.ref.acceptor_configuration.ref.max_connections,
      _transport.ref.acceptor_configuration.ref.receive_buffer_size,
      _transport.ref.acceptor_configuration.ref.send_buffer_size,
    );
    _callbacks.putConnect(fd, completer);
    using((arena) => _bindings.transport_channel_connect(_channelPointer, fd, host.toNativeUtf8(allocator: arena).cast(), port));
    return completer.future;
  }
}
