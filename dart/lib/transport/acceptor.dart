import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportAcceptor {
  final TransportBindings _bindings;

  late final TransportAcceptorConfiguration configuration;
  late final Pointer<transport_acceptor_t> acceptor;

  TransportAcceptor(this._bindings);

  void initialize(TransportAcceptorConfiguration configuration, String host, int port) {
    this.configuration = configuration;
    using((Arena arena) {
      final acceptorConfiguration = arena<transport_acceptor_configuration>();
      acceptorConfiguration.ref.backlog = configuration.backlog;
      acceptor = _bindings.transport_initialize_acceptor(acceptorConfiguration, host.toNativeUtf8().cast(), port);
    });
  }

  void close() => _bindings.transport_close_acceptor(acceptor);
}
