import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/communicator.dart';
import 'package:iouring_transport/transport/extensions.dart';
import 'package:iouring_transport/transport/state.dart';

import 'bindings.dart';
import 'channels.dart';
import 'configuration.dart';
import 'constants.dart';
import 'defaults.dart';

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> workerPointer;
  final TransportBindings _bindings;
  final int readTimeout;
  final int writeTimeout;
  final TransportEventStates eventStates;

  late final int fd;

  var _active = true;
  bool get active => _active;
  final _closer = Completer();

  TransportServer(
    this.pointer,
    this.workerPointer,
    this._bindings,
    this.eventStates,
    this.readTimeout,
    this.writeTimeout,
  ) {
    fd = pointer.ref.fd;
  }

  Stream<TransportServerStreamCommunicator> accept(Pointer<transport_worker_t> workerPointer) {
    final controller = StreamController<TransportChannel>();
    eventStates.setAccept(fd, controller);
    _bindings.transport_worker_accept(
      workerPointer,
      pointer,
    );
    return controller.stream.map((channel) => TransportServerStreamCommunicator(this, channel));
  }

  @pragma(preferInlinePragma)
  void onRemove() {
    if (!_active) _closer.complete();
  }

  Future<void> close() async {
    if (_active) {
      _active = false;
      _bindings.transport_worker_cancel(workerPointer);
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
  final TransportEventStates _eventStates;

  TransportServerRegistry(this._bindings, this._workerPointer, this._eventStates);

  TransportServer createTcp(String host, int port, {TransportTcpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.tcpServer();
    final instance = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_tcp(
          _tcpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _workerPointer,
        _bindings,
        _eventStates,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
      ),
    );
    _servers[instance.pointer.ref.fd] = instance;
    return instance;
  }

  TransportServer createUdp(String host, int port, {TransportUdpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpServer();
    final instance = using(
      (Arena arena) {
        final pointer = _bindings.transport_server_initialize_udp(
          _udpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        );
        if (configuration.multicastManager != null) {
          configuration.multicastManager!.subscribe(
            onAddMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_add_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.getMemberShipIndex(_bindings),
              ),
            ),
            onDropMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_drop_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.getMemberShipIndex(_bindings),
              ),
            ),
            onAddSourceMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_add_source_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.sourceAddress.toNativeUtf8(allocator: arena).cast(),
              ),
            ),
            onDropSourceMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_drop_source_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.sourceAddress.toNativeUtf8(allocator: arena).cast(),
              ),
            ),
          );
        }
        return TransportServer(
          pointer,
          _workerPointer,
          _bindings,
          _eventStates,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
        );
      },
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
        _workerPointer,
        _bindings,
        _eventStates,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
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
        _workerPointer,
        _bindings,
        _eventStates,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
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
    int flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (serverConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (serverConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (serverConfiguration.socketKeepalive == true) flags |= transportSocketOptionSocketKeepalive;
    if (serverConfiguration.ipFreebind == true) flags |= transportSocketOptionIpFreebind;
    if (serverConfiguration.tcpQuickack == true) flags |= transportSocketOptionTcpQuickack;
    if (serverConfiguration.tcpDeferAccept == true) flags |= transportSocketOptionTcpDeferAccept;
    if (serverConfiguration.tcpFastopen == true) flags |= transportSocketOptionTcpFastopen;
    if (serverConfiguration.tcpNodelay == true) flags |= transportSocketOptionTcpNodelay;
    if (serverConfiguration.socketMaxConnections != null) {
      nativeServerConfiguration.ref.socket_max_connections = serverConfiguration.socketMaxConnections!;
    }
    if (serverConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeServerConfiguration.ref.socket_receive_buffer_size = serverConfiguration.socketReceiveBufferSize!;
    }
    if (serverConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeServerConfiguration.ref.socket_send_buffer_size = serverConfiguration.socketSendBufferSize!;
    }
    if (serverConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeServerConfiguration.ref.socket_receive_low_at = serverConfiguration.socketReceiveLowAt!;
    }
    if (serverConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeServerConfiguration.ref.socket_send_low_at = serverConfiguration.socketSendLowAt!;
    }
    if (serverConfiguration.ipTtl != null) {
      flags |= transportSocketOptionIpTtl;
      nativeServerConfiguration.ref.ip_ttl = serverConfiguration.ipTtl!;
    }
    if (serverConfiguration.tcpKeepAliveIdle != null) {
      flags |= transportSocketOptionTcpKeepidle;
      nativeServerConfiguration.ref.tcp_keep_alive_idle = serverConfiguration.tcpKeepAliveIdle!;
    }
    if (serverConfiguration.tcpKeepAliveMaxCount != null) {
      flags |= transportSocketOptionTcpKeepcnt;
      nativeServerConfiguration.ref.tcp_keep_alive_max_count = serverConfiguration.tcpKeepAliveMaxCount!;
    }
    if (serverConfiguration.tcpKeepAliveIdle != null) {
      flags |= transportSocketOptionTcpKeepintvl;
      nativeServerConfiguration.ref.tcp_keep_alive_individual_count = serverConfiguration.tcpKeepAliveIdle!;
    }
    if (serverConfiguration.tcpMaxSegmentSize != null) {
      flags |= transportSocketOptionTcpMaxseg;
      nativeServerConfiguration.ref.tcp_max_segment_size = serverConfiguration.tcpMaxSegmentSize!;
    }
    if (serverConfiguration.tcpSynCount != null) {
      flags |= transportSocketOptionTcpSyncnt;
      nativeServerConfiguration.ref.tcp_syn_count = serverConfiguration.tcpSynCount!;
    }
    nativeServerConfiguration.ref.socket_configuration_flags = flags;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _udpConfiguration(TransportUdpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    int flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (serverConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (serverConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (serverConfiguration.socketBroadcast == true) flags |= transportSocketOptionSocketBroadcast;
    if (serverConfiguration.ipFreebind == true) flags |= transportSocketOptionIpFreebind;
    if (serverConfiguration.ipMulticastAll == true) flags |= transportSocketOptionIpMulticastAll;
    if (serverConfiguration.ipMulticastLoop == true) flags |= transportSocketOptionIpMulticastLoop;
    if (serverConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeServerConfiguration.ref.socket_receive_buffer_size = serverConfiguration.socketReceiveBufferSize!;
    }
    if (serverConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeServerConfiguration.ref.socket_send_buffer_size = serverConfiguration.socketSendBufferSize!;
    }
    if (serverConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeServerConfiguration.ref.socket_receive_low_at = serverConfiguration.socketReceiveLowAt!;
    }
    if (serverConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeServerConfiguration.ref.socket_send_low_at = serverConfiguration.socketSendLowAt!;
    }
    if (serverConfiguration.ipTtl != null) {
      flags |= transportSocketOptionIpTtl;
      nativeServerConfiguration.ref.ip_ttl = serverConfiguration.ipTtl!;
    }
    if (serverConfiguration.ipMulticastTtl != null) {
      flags |= transportSocketOptionIpMulticastTtl;
      nativeServerConfiguration.ref.ip_multicast_ttl = serverConfiguration.ipMulticastTtl!;
    }
    if (serverConfiguration.ipMulticastInterface != null) {
      flags |= transportSocketOptionIpMulticastIf;
      final interface = serverConfiguration.ipMulticastInterface!;
      nativeServerConfiguration.ref.ip_multicast_interface = _bindings.transport_socket_multicast_create_request(
        interface.groupAddress.toNativeUtf8(allocator: allocator).cast(),
        interface.localAddress.toNativeUtf8(allocator: allocator).cast(),
        interface.getMemberShipIndex(_bindings),
      );
    }
    nativeServerConfiguration.ref.socket_configuration_flags = flags;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixStreamConfiguration(TransportUnixStreamServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    int flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (serverConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (serverConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (serverConfiguration.socketKeepalive == true) flags |= transportSocketOptionSocketKeepalive;
    if (serverConfiguration.socketMaxConnections != null) {
      nativeServerConfiguration.ref.socket_max_connections = serverConfiguration.socketMaxConnections!;
    }
    if (serverConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeServerConfiguration.ref.socket_receive_buffer_size = serverConfiguration.socketReceiveBufferSize!;
    }
    if (serverConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeServerConfiguration.ref.socket_send_buffer_size = serverConfiguration.socketSendBufferSize!;
    }
    if (serverConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeServerConfiguration.ref.socket_receive_low_at = serverConfiguration.socketReceiveLowAt!;
    }
    if (serverConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeServerConfiguration.ref.socket_send_low_at = serverConfiguration.socketSendLowAt!;
    }
    nativeServerConfiguration.ref.socket_configuration_flags = flags;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixDatagramConfiguration(TransportUnixDatagramServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    int flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (serverConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (serverConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (serverConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeServerConfiguration.ref.socket_receive_buffer_size = serverConfiguration.socketReceiveBufferSize!;
    }
    if (serverConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeServerConfiguration.ref.socket_send_buffer_size = serverConfiguration.socketSendBufferSize!;
    }
    if (serverConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeServerConfiguration.ref.socket_receive_low_at = serverConfiguration.socketReceiveLowAt!;
    }
    if (serverConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeServerConfiguration.ref.socket_send_low_at = serverConfiguration.socketSendLowAt!;
    }
    nativeServerConfiguration.ref.socket_configuration_flags = flags;
    return nativeServerConfiguration;
  }
}
