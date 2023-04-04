import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/defaults.dart';

import 'bindings.dart';
import 'channels.dart';
import 'configuration.dart';
import 'constants.dart';
import 'payload.dart';

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final TransportBindings _bindings;

  late final StreamController<TransportInboundPayload> controller;
  late final Stream<TransportInboundPayload> stream;
  late final void Function(TransportInboundChannel channel)? acceptor;

  TransportServer(this.pointer, this._bindings) {
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

  void shutdown() {
    _bindings.transport_server_shutdown(pointer);
    controller.close();
  }
}

class TransportServerRegistry {
  final _servers = <int, TransportServer>{};
  final _serversByClients = <int, TransportServer>{};

  final TransportBindings _bindings;

  TransportServerRegistry(this._bindings);

  TransportServer createTcp(String host, int port, {TransportTcpServerConfiguration? configuration}) {
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_tcp(
          _tcpConfiguration(configuration ?? TransportDefaults.tcpServer(), arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _bindings,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUdp(String host, int port, {TransportUdpServerConfiguration? configuration}) {
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_udp(
          _udpConfiguration(configuration ?? TransportDefaults.udpServer(), arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _bindings,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixStream(String path, {TransportUnixStreamServerConfiguration? configuration}) {
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_stream(
          _unixStreamConfiguration(configuration ?? TransportDefaults.unixStreamServer(), arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _bindings,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_dgram(
          _unixDatagramConfiguration(configuration ?? TransportDefaults.unixDatagramServer(), arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _bindings,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  @pragma(preferInlinePragma)
  TransportServer getByServer(int fd) => _servers[fd]!;

  @pragma(preferInlinePragma)
  TransportServer getByClient(int fd) => _serversByClients[fd]!;

  @pragma(preferInlinePragma)
  void mapClient(int serverFd, int clientFd) => _serversByClients[clientFd] = _servers[serverFd]!;

  void shutdown() => _servers.values.forEach((server) => server.shutdown());

  Pointer<transport_server_configuration_t> _tcpConfiguration(TransportTcpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.max_connections = serverConfiguration.maxConnections;
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _udpConfiguration(TransportUdpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixStreamConfiguration(TransportUnixStreamServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.max_connections = serverConfiguration.maxConnections;
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixDatagramConfiguration(TransportUnixDatagramServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    return nativeServerConfiguration;
  }
}
