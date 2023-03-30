import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels.dart';
import 'constants.dart';
import 'model.dart';
import 'payload.dart';

class TransportServerInstance {
  final Pointer<transport_server_t> pointer;
  final TransportBindings _bindings;

  late final StreamController<TransportInboundPayload> controller;
  late final Stream<TransportInboundPayload> stream;
  late final void Function(TransportInboundChannel channel)? acceptor;

  TransportServerInstance(this.pointer, this._bindings) {
    controller = StreamController();
    stream = controller.stream;
  }

  void accept(Pointer<transport_worker_t> workerPointer, void Function(TransportInboundChannel channel) acceptor) {
    this.acceptor = acceptor;
    _bindings.transport_worker_accept(
      workerPointer,
      pointer,
    );
  }

  void close() => controller.close();
}

class TransportServer {
  final _serverIntances = <int, TransportServerInstance>{};

  final Pointer<transport_server_configuration_t> _configuration;
  final TransportBindings _bindings;

  TransportServer(this._configuration, this._bindings);

  TransportServerInstance create(TransportUri uri) {
    final instance = using(
      (Arena arena) {
        switch (uri.mode) {
          case TransportSocketMode.tcp:
            return TransportServerInstance(
              _bindings.transport_server_initialize_tcp(_configuration, uri.inetHost!.toNativeUtf8().cast(), uri.inetPort!),
              _bindings,
            );
          case TransportSocketMode.udp:
            return TransportServerInstance(
              _bindings.transport_server_initialize_udp(_configuration, uri.inetHost!.toNativeUtf8().cast(), uri.inetPort!),
              _bindings,
            );
          case TransportSocketMode.unixDgram:
            return TransportServerInstance(
              _bindings.transport_server_initialize_unix_dgram(
                _configuration,
                uri.unixPath!.toNativeUtf8().cast(),
                uri.unixPath!.length,
              ),
              _bindings,
            );
          case TransportSocketMode.unixStream:
            return TransportServerInstance(
              _bindings.transport_server_initialize_unix_stream(
                _configuration,
                uri.unixPath!.toNativeUtf8().cast(),
                uri.unixPath!.length,
              ),
              _bindings,
            );
        }
      },
    );
    _serverIntances[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServerInstance get(int fd) => _serverIntances[fd]!;
}
