import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'listener.dart';

class TransportConnection {
  final TransportBindings _bindings;
  final Pointer<transport_context_t> _context;
  final TransportListener _listener;
  final StreamController<TransportChannel> _serverChannels = StreamController();
  final StreamController<TransportChannel> _clientChannels = StreamController();

  TransportConnection(this._bindings, this._context, this._listener);

  Stream<TransportChannel> bind(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_socket_bind(socket, host.toNativeUtf8().cast(), port, 0);
    _bindings.transport_queue_accept(_context, socket);
    return _acceptClient();
  }

  Stream<TransportChannel> connect(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_queue_connect(_context, socket, host.toNativeUtf8().cast(), port);
    return _acceptServer();
  }

  Stream<TransportChannel> _acceptClient() {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_request> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_ACCEPT) {
        final clientDescriptor = cqe.ref.res;
        calloc.free(userData);
        calloc.free(cqe);
        _clientChannels.add(TransportChannel(_bindings, _context, clientDescriptor, _listener)..start());
      }
    });
    _clientChannels.onCancel = subscription.cancel;
    return _clientChannels.stream;
  }

  Stream<TransportChannel> _acceptServer() {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_request> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_CONNECT) {
        final serverDescriptor = userData.ref.fd;
        calloc.free(userData);
        calloc.free(cqe);
        _serverChannels.add(TransportChannel(_bindings, _context, serverDescriptor, _listener)..start());
      }
    });
    _serverChannels.onCancel = subscription.cancel;
    return _serverChannels.stream;
  }
}
