import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/acceptor.dart';
import 'dart:ffi';

import 'package:iouring_transport/transport/channel.dart';
import 'package:iouring_transport/transport/connector.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportConnection {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportLoopConfiguration _loopConfiguration;
  late TransportAcceptor _acceptor;
  late TransportConnector _connector;

  TransportConnection(this._bindings, this._loopConfiguration, this._ring) {
    _acceptor = TransportAcceptor(_bindings, _loopConfiguration, _ring);
    _connector = TransportConnector(_bindings, _loopConfiguration, _ring);
  }

  Future<TransportChannel> bind(String host, int port) async {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_socket_bind(socket, host.toNativeUtf8().cast(), port, 0);
    _bindings.transport_queue_accept(_ring, socket);
    return _acceptor.accept().then((descriptor) => TransportChannel(_bindings, _loopConfiguration, _ring, descriptor)..start());
  }

  Future<TransportChannel> connect(String host, int port) async {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_queue_connect(_ring, socket, host.toNativeUtf8().cast(), port);
    return _connector.connect().then((descriptor) => TransportChannel(_bindings, _loopConfiguration, _ring, descriptor)..start());
  }
}
