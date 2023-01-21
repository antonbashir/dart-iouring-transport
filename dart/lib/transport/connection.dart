import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/socket.dart';
import 'listener.dart';

class TransportConnection {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportListener _listener;
  final StreamController<TransportSocketChannel> _serverChannels = StreamController();
  final StreamController<TransportSocketChannel> _clientChannels = StreamController();

  TransportConnection(this._bindings, this._ring, this._listener);

  Stream<TransportSocketChannel> bind(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_socket_bind(socket, host.toNativeUtf8().cast(), port, 0);
    _bindings.transport_queue_accept(_ring, socket);
    return _acceptClient();
  }

  Stream<TransportSocketChannel> connect(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_queue_connect(_ring, socket, host.toNativeUtf8().cast(), port);
    return _acceptServer();
  }

  Stream<TransportSocketChannel> _acceptClient() {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_request> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_ACCEPT) {
        final clientDescriptor = cqe.ref.res;
        calloc.free(userData);
        calloc.free(cqe);
        _clientChannels.add(TransportSocketChannel(_bindings, _ring, clientDescriptor, _listener)..start());
      }
    });
    _clientChannels.onCancel = subscription.cancel;
    return _clientChannels.stream;
  }

  Stream<TransportSocketChannel> _acceptServer() {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_request> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_CONNECT) {
        final serverDescriptor = userData.ref.fd;
        calloc.free(userData);
        calloc.free(cqe);
        _serverChannels.add(TransportSocketChannel(_bindings, _ring, serverDescriptor, _listener)..start());
      }
    });
    _serverChannels.onCancel = subscription.cancel;
    return _serverChannels.stream;
  }
}
