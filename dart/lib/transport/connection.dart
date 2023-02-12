import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'configuration.dart';

class TransportConnection {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final Pointer<transport_controller_t> _controller;
  final TransportConnectionConfiguration _configuration;
  final TransportChannelConfiguration _channelConfiguration;
  final StreamController<TransportChannel> clientChannels = StreamController();
  final StreamController<TransportChannel> serverChannels = StreamController();

  late final Pointer<transport_acceptor_t> _acceptor;
  late final Pointer<transport_connector_t> _connector;

  late int _socket;

  TransportConnection(
    this._configuration,
    this._channelConfiguration,
    this._bindings,
    this._transport,
    this._controller,
  );

  void initialize() {
    using((Arena arena) {
      final configuration = arena<transport_connection_configuration_t>();
      configuration.ref.verbose = false;
      _connection = _bindings.transport_initialize_connection(
        _transport,
        _controller,
        configuration,
        _acceptPort.sendPort.nativePort,
        _connectPort.sendPort.nativePort,
      );
      _socket = _bindings.transport_socket_create();
    });
  }

  void close() {
    _acceptPort.close();
    _connectPort.close();
    _bindings.transport_close_connection(_connection);
  }

  Stream<TransportChannel> bind(String host, int port) {
    _bindings.transport_socket_bind(_socket, host.toNativeUtf8().cast(), port, _configuration.backlog);
    _bindings.transport_connection_queue_accept(_connection, _socket);
    return clientChannels.stream;
  }

  Stream<TransportChannel> connect(String host, int port) {
    _bindings.transport_connection_queue_connect(_connection, _socket, host.toNativeUtf8().cast(), port);
    return serverChannels.stream;
  }
}
