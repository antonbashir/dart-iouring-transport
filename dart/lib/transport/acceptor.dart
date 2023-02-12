import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportAcceptor {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final Pointer<transport_controller_t> _controller;
  final TransportAcceptorConfiguration _configuration;

  late final Pointer<transport_acceptor_t> _acceptor;

  TransportAcceptor(
    this._configuration,
    this._bindings,
    this._transport,
    this._controller,
  );

  void close() {
    _bindings.transport_close_acceptor(_acceptor);
  }

  void accept(String host, int port) {
    using((Arena arena) {
      final configuration = arena<transport_acceptor_configuration>();
      configuration.ref.backlog = _configuration.backlog;
      configuration.ref.ring_size = _configuration.ringSize;
      _acceptor = _bindings.transport_initialize_acceptor(
        _transport,
        _controller,
        configuration,
        host.toNativeUtf8().cast(),
        port,
      );
    });
    _bindings.transport_acceptor_accept(_acceptor);
  }
}
