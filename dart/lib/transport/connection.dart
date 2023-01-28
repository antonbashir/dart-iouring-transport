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
  final Pointer<transport_listener_t> _listener;
  final TransportConnectionConfiguration _configuration;
  final TransportChannelConfiguration _channelConfiguration;
  final StreamController<TransportChannel> clientChannels = StreamController();
  final StreamController<TransportChannel> serverChannels = StreamController();

  late final Pointer<transport_connection_t> _connection;
  late final RawReceivePort _acceptPort = RawReceivePort(_handleAccept);
  late final RawReceivePort _connectPort = RawReceivePort(_handleConnect);

  TransportConnection(
    this._configuration,
    this._channelConfiguration,
    this._bindings,
    this._transport,
    this._listener,
  );

  void initialize() {
    using((Arena arena) {
      final configuration = arena<transport_connection_configuration_t>();
      configuration.ref.verbose = false;
      _connection = _bindings.transport_initialize_connection(
        _transport,
        _listener,
        configuration,
        _acceptPort.sendPort.nativePort,
        _connectPort.sendPort.nativePort,
      );
    });
  }

  void close() {
    _acceptPort.close();
    _connectPort.close();
    _bindings.transport_close_connection(_connection);
  }

  Stream<TransportChannel> bind(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_socket_bind(socket, host.toNativeUtf8().cast(), port, 0);
    _bindings.transport_connection_queue_accept(_connection, socket);
    return clientChannels.stream;
  }

  Stream<TransportChannel> connect(String host, int port) {
    final socket = _bindings.transport_socket_create();
    _bindings.transport_connection_queue_connect(_connection, socket, host.toNativeUtf8().cast(), port);
    return serverChannels.stream;
  }

  void _handleAccept(int payloadPointer) {
    Pointer<transport_accept_payload> payload = Pointer.fromAddress(payloadPointer);
    if (payload == nullptr) return;
    clientChannels.add(TransportChannel(_bindings, _channelConfiguration, _transport, _listener, payload.ref.fd));
    _bindings.transport_connection_free_accept_payload(_connection, payload);
  }

  void _handleConnect(int payloadPointer) {
    Pointer<transport_accept_payload> payload = Pointer.fromAddress(payloadPointer);
    if (payload == nullptr) return;
    serverChannels.add(TransportChannel(_bindings, _channelConfiguration, _transport, _listener, payload.ref.fd));
    _bindings.transport_connection_free_accept_payload(_connection, payload);
  }
}
