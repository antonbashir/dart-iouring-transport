import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportAcceptor {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final TransportAcceptorConfiguration _configuration;

  late final Pointer<transport_acceptor_t> acceptor;

  TransportAcceptor(
    this._configuration,
    this._bindings,
    this._transport,
  );

  void initialize(String host, int port) {
    using((Arena arena) {
      final configuration = arena<transport_acceptor_configuration>();
      configuration.ref.backlog = _configuration.backlog;
      configuration.ref.ring_size = _configuration.ringSize;
      acceptor = _bindings.transport_initialize_acceptor(
        _transport,
        configuration,
        host.toNativeUtf8().cast(),
        port,
      );
    });
  }

  void close() {
    _bindings.transport_close_acceptor(acceptor);
  }

  void accept() {
    _bindings.transport_acceptor_accept(acceptor);
  }
}
