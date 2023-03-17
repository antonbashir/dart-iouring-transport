import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

class TransportAcceptor {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transportPointer;

  late final Pointer<transport_acceptor_t> pointer;

  TransportAcceptor(this._transportPointer, this._bindings);

  void accept(String host, int port) {
    pointer = using((arena) => _bindings.transport_acceptor_initialize(
          _transportPointer.ref.acceptor_configuration,
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ));
    _bindings.transport_channel_accept(_bindings.transport_channel_pool_next(_transportPointer.ref.channels), pointer);
  }
}
