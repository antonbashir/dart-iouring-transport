import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'configuration.dart';
import 'listener.dart';

class TransportConnection {
  final TransportBindings _bindings;
  final Pointer<transport_context_t> _context;
  final TransportListener _listener;
  final StreamController<TransportChannel> _serverChannels = StreamController();
  final StreamController<TransportChannel> _clientChannels = StreamController();

  TransportConnection(this._bindings, this._context, this._listener);

  Stream<TransportChannel> bind(String host, int port, TransportChannelConfiguration configuration) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_socket_bind(socket, host.toNativeUtf8().cast(), port, 0);
    _bindings.transport_queue_accept(_context, socket);
    return _acceptClient(configuration);
  }

  Stream<TransportChannel> connect(String host, int port, TransportChannelConfiguration configuration) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_queue_connect(_context, socket, host.toNativeUtf8().cast(), port);
    return _acceptServer(configuration);
  }

  Stream<TransportChannel> _acceptClient(TransportChannelConfiguration configuration) {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_message> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData == nullptr) return;
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_ACCEPT) {
        final clientDescriptor = cqe.ref.res;
        _bindings.transport_free_message(_context, userData.cast(), userData.ref.type);
        _bindings.transport_free_cqe(_context, cqe);
        final channel = using((Arena arena) {
          final channelConfiguration = arena<transport_channel_configuration_t>();
          channelConfiguration.ref.buffer_initial_capacity = configuration.bufferInitialCapacity;
          channelConfiguration.ref.buffer_limit = configuration.bufferLimit;
          return _bindings.transport_initialize_channel(_context, channelConfiguration, clientDescriptor);
        });
        _clientChannels.add(TransportChannel(_bindings, channel, _listener, configuration)..start(onStop: () => _clientChannels.close()));
      }
    });
    _clientChannels.onCancel = subscription.cancel;
    return _clientChannels.stream;
  }

  Stream<TransportChannel> _acceptServer(TransportChannelConfiguration configuration) {
    final subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_accept_message> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData == nullptr) return;
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_CONNECT) {
        final serverDescriptor = userData.ref.fd;
        _bindings.transport_free_message(_context, userData.cast(), userData.ref.type);
        _bindings.transport_free_cqe(_context, cqe);
        final channel = using((Arena arena) {
          final channelConfiguration = arena<transport_channel_configuration_t>();
          channelConfiguration.ref.buffer_initial_capacity = configuration.bufferInitialCapacity;
          channelConfiguration.ref.buffer_limit = configuration.bufferLimit;
          return _bindings.transport_initialize_channel(_context, channelConfiguration, serverDescriptor);
        });
        _serverChannels.add(TransportChannel(_bindings, channel, _listener, configuration)..start(onStop: () => _serverChannels.close()));
      }
    });
    _serverChannels.onCancel = subscription.cancel;
    return _serverChannels.stream;
  }
}
