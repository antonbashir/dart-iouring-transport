import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportAcceptor {
  final TransportBindings _bindings;
  late final Pointer<transport_acceptor_t> acceptor;

  TransportAcceptor(this._bindings);

  void initialize(TransportAcceptorConfiguration _configuration, String host, int port) {
    using((Arena arena) {
      final configuration = arena<transport_acceptor_configuration>();
      configuration.ref.backlog = _configuration.backlog;
      acceptor = _bindings.transport_initialize_acceptor(
        configuration,
        host.toNativeUtf8().cast(),
        port,
      );
    });
  }

  void close() => _bindings.transport_close_acceptor(acceptor);
}
