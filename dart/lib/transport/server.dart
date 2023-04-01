import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/constants.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final TransportBindings _bindings;

  late final StreamController<TransportInboundPayload> controller;
  late final Stream<TransportInboundPayload> stream;
  late final void Function(TransportInboundChannel channel)? acceptor;
  late final TransportSocketFamily socketFamily;

  TransportServer(this.pointer, this._bindings) {
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

  void shutdown() {
    _bindings.transport_server_shutdown(pointer);
    controller.close();
  }
}

class TransportServerRegistry {
  final _servers = <int, TransportServer>{};
  final _serversByClients = <int, TransportServer>{};

  final Pointer<transport_server_configuration_t> _configuration;
  final TransportBindings _bindings;

  TransportServerRegistry(this._configuration, this._bindings);

  TransportServer createTcp(String host, int port) {
    final instance = TransportServer(
      _bindings.transport_server_initialize_tcp(_configuration, host.toNativeUtf8().cast(), port),
      _bindings,
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUdp(String host, int port) {
    final instance = TransportServer(
      _bindings.transport_server_initialize_udp(_configuration, host.toNativeUtf8().cast(), port),
      _bindings,
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixStream(String path) {
    final instance = TransportServer(
      _bindings.transport_server_initialize_unix_stream(_configuration, path.toNativeUtf8().cast(), path.length),
      _bindings,
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixDatagram(String path) {
    final instance = TransportServer(
      _bindings.transport_server_initialize_unix_dgram(_configuration, path.toNativeUtf8().cast(), path.length),
      _bindings,
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer getByServer(int fd) => _servers[fd]!;

  TransportServer getByClient(int fd) => _serversByClients[fd]!;

  void mapClient(int serverFd, int clientFd) {
    _serversByClients[clientFd] = _servers[serverFd]!;
  }

  void shutdown() => _servers.values.forEach((server) => server.shutdown());
}
