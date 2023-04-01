import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/constants.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';

class TransportServerInstance {
  final Pointer<transport_server_t> pointer;
  final TransportBindings _bindings;

  late final StreamController<TransportInboundPayload> controller;
  late final Stream<TransportInboundPayload> stream;
  late final void Function(TransportInboundChannel channel)? acceptor;
  late final TransportSocketFamily socketFamily;

  TransportServerInstance(this.pointer, this._bindings) {
    controller = StreamController();
    stream = controller.stream;
    socketFamily = TransportSocketFamily.values[pointer.ref.family];
  }

  void accept(Pointer<transport_worker_t> workerPointer, void Function(TransportInboundChannel channel) acceptor) {
    this.acceptor = acceptor;
    _bindings.transport_worker_accept(
      workerPointer,
      pointer,
    );
  }

  void close() {
    _bindings.transport_server_shutdown(pointer);
    controller.close();
  }
}

class TransportServer {
  final _serverIntances = <int, TransportServerInstance>{};
  final _serversByClients = <int, TransportServerInstance>{};

  final Pointer<transport_server_configuration_t> _configuration;
  final TransportBindings _bindings;

  TransportServer(this._configuration, this._bindings);

  TransportServerInstance createTcp(String host, int port) {
    final instance = TransportServerInstance(
      _bindings.transport_server_initialize_tcp(_configuration, host.toNativeUtf8().cast(), port),
      _bindings,
    );
    _serverIntances[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServerInstance createUdp(String host, int port) {
    final instance = TransportServerInstance(
      _bindings.transport_server_initialize_udp(_configuration, host.toNativeUtf8().cast(), port),
      _bindings,
    );
    _serverIntances[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServerInstance createUnixStream(String path) {
    final instance = TransportServerInstance(
      _bindings.transport_server_initialize_unix_stream(_configuration, path.toNativeUtf8().cast(), path.length),
      _bindings,
    );
    _serverIntances[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServerInstance createUnixDgram(String path) {
    final instance = TransportServerInstance(
      _bindings.transport_server_initialize_unix_dgram(_configuration, path.toNativeUtf8().cast(), path.length),
      _bindings,
    );
    _serverIntances[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServerInstance getByServer(int fd) => _serverIntances[fd]!;

  TransportServerInstance getByClient(int fd) => _serverIntances[fd]!;

  void mapClient(int serverFd, int clientFd) {
    _serversByClients[clientFd] = _serverIntances[serverFd]!;
  }

  void shutdown() => _serverIntances.values.forEach((server) => server.close());
}
