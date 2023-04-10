import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels.dart';
import 'configuration.dart';
import 'constants.dart';
import 'defaults.dart';
import 'payload.dart';

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportRetryConfiguration retry;

  late final int fd;
  late final StreamController<TransportInboundPayload> controller;
  late final Stream<TransportInboundPayload> stream;
  late final void Function(TransportInboundChannel channel)? acceptor;

  var _active = true;
  bool get active => _active;
  final _closer = Completer();

  TransportServer(this.pointer, this._bindings, this.retry, this._workerPointer) {
    controller = StreamController();
    stream = controller.stream;
    fd = pointer.ref.fd;
  }

  void accept(Pointer<transport_worker_t> workerPointer, void Function(TransportInboundChannel channel) acceptor) {
    this.acceptor = acceptor;
    _bindings.transport_worker_accept(
      workerPointer,
      pointer,
    );
  }

  void onRemove() {
    if (!_active) _closer.complete();
  }

  Future<void> close() async {
    if (_active) {
      _active = false;
      controller.close();
      _bindings.transport_worker_cancel(_workerPointer);
      await _closer.future;
      _bindings.transport_close_descritor(pointer.ref.fd);
      _bindings.transport_server_destroy(pointer);
    }
  }
}

class TransportServerRegistry {
  final _servers = <int, TransportServer>{};
  final _serversByClients = <int, TransportServer>{};
  final Pointer<transport_worker_t> _workerPointer;

  final TransportBindings _bindings;

  TransportServerRegistry(this._bindings, this._workerPointer);

  TransportServer createTcp(String host, int port, {TransportTcpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.tcpServer();
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_tcp(
          _tcpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _bindings,
        configuration.retryConfiguration,
        _workerPointer,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUdp(String host, int port, {TransportUdpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpServer();
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_udp(
          _udpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _bindings,
        configuration.retryConfiguration,
        _workerPointer,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixStream(String path, {TransportUnixStreamServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixStreamServer();
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_stream(
          _unixStreamConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _bindings,
        configuration.retryConfiguration,
        _workerPointer,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUnixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramServer();
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_dgram(
          _unixDatagramConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _bindings,
        configuration.retryConfiguration,
        _workerPointer,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  @pragma(preferInlinePragma)
  TransportServer? getByServer(int fd) => _servers[fd];

  @pragma(preferInlinePragma)
  TransportServer? getByClient(int fd) => _serversByClients[fd];

  @pragma(preferInlinePragma)
  void addClient(int serverFd, int clientFd) => _serversByClients[clientFd] = _servers[serverFd]!;

  @pragma(preferInlinePragma)
  void removeClient(int fd) {
    _serversByClients.remove(fd);
  }

  @pragma(preferInlinePragma)
  void removeServer(int fd) {
    _servers.remove(fd)?.onRemove();
  }

  Future<void> close() async {
    await Future.wait(_servers.values.map((server) => server.close()));
  }

  Pointer<transport_server_configuration_t> _tcpConfiguration(TransportTcpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.max_connections = serverConfiguration.maxConnections;
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    nativeServerConfiguration.ref.read_timeout = serverConfiguration.readTimeout.inSeconds;
    nativeServerConfiguration.ref.write_timeout = serverConfiguration.writeTimeout.inSeconds;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _udpConfiguration(TransportUdpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    nativeServerConfiguration.ref.read_timeout = serverConfiguration.readTimeout.inSeconds;
    nativeServerConfiguration.ref.write_timeout = serverConfiguration.writeTimeout.inSeconds;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixStreamConfiguration(TransportUnixStreamServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.max_connections = serverConfiguration.maxConnections;
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    nativeServerConfiguration.ref.read_timeout = serverConfiguration.readTimeout.inSeconds;
    nativeServerConfiguration.ref.write_timeout = serverConfiguration.writeTimeout.inSeconds;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixDatagramConfiguration(TransportUnixDatagramServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    nativeServerConfiguration.ref.receive_buffer_size = serverConfiguration.receiveBufferSize;
    nativeServerConfiguration.ref.send_buffer_size = serverConfiguration.sendBufferSize;
    nativeServerConfiguration.ref.read_timeout = serverConfiguration.readTimeout.inSeconds;
    nativeServerConfiguration.ref.write_timeout = serverConfiguration.writeTimeout.inSeconds;
    return nativeServerConfiguration;
  }
}
