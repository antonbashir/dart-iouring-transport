import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'configuration.dart';

class TransportConnector {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final Pointer<transport_controller_t> _controller;
  final TransportConnectorConfiguration _configuration;

  late final Pointer<transport_connector_t> _connector;

  TransportConnector(
    this._configuration,
    this._bindings,
    this._transport,
    this._controller,
  );

  void initialize(String host, int port) {
    using((Arena arena) {
      final configuration = arena<transport_connector_configuration>();
      _connector = _bindings.transport_initialize_connector(
        _transport,
        _controller,
        configuration,
        host.toNativeUtf8().cast(),
        port,
      );
    });
  }

  void close() {
    _bindings.transport_close_connector(_connector);
  }

  void connect() {
    _bindings.transport_connector_connect(_connector);
  }
}
