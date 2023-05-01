import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../links.dart';
import '../payload.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../constants.dart';
import '../defaults.dart';
import '../exception.dart';
import '../extensions.dart';
import 'configuration.dart';
import 'server.dart';
import 'package:meta/meta.dart';

class TransportServerRegistry {
  final _servers = <int, TransportServer>{};
  final _serverConnections = <int, TransportServer>{};

  @visibleForTesting
  Map<int, TransportServer> get servers => _servers;

  @visibleForTesting
  Map<int, TransportServer> get serverConnections => _serverConnections;

  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final TransportBuffers _buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;

  TransportServerRegistry(this._bindings, this._callbacks, this._workerPointer, this._buffers, this._payloadPool, this._links);

  TransportServer createTcp(String host, int port, {TransportTcpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.tcpServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException("[server] out of memory");
        }
        final result = _bindings.transport_server_initialize_tcp(
          pointer,
          _tcpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descritor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException("[server] code = $result, message = ${result.kernelErrorToString(_bindings)}");
          }
          throw TransportInitializationException("[server] unable to set socket option: ${-result}");
        }
        return TransportServer(
          pointer,
          _workerPointer,
          _bindings,
          _callbacks,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
          _buffers,
          this,
          _payloadPool,
          _links,
        );
      },
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUdp(String host, int port, {TransportUdpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException("[server] out of memory");
        }
        final result = _bindings.transport_server_initialize_udp(
          pointer,
          _udpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descritor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException("[server] code = $result, message = ${result.kernelErrorToString(_bindings)}");
          }
          throw TransportInitializationException("[server] unable to set socket option: ${-result}");
        }
        if (configuration.multicastManager != null) {
          configuration.multicastManager!.subscribe(
            onAddMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_add_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.getMembershipIndex(_bindings),
              ),
            ),
            onDropMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_drop_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.getMembershipIndex(_bindings),
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
          _callbacks,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
          _buffers,
          this,
          _payloadPool,
          _links,
        );
      },
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUnixStream(String path, {TransportUnixStreamServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixStreamServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException("[server] out of memory");
        }
        final result = _bindings.transport_server_initialize_unix_stream(
          pointer,
          _unixStreamConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descritor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException("[server] code = $result, message = ${result.kernelErrorToString(_bindings)}");
          }
          throw TransportInitializationException("[server] unable to set socket option: ${-result}");
        }
        return TransportServer(
          pointer,
          _workerPointer,
          _bindings,
          _callbacks,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
          _buffers,
          this,
          _payloadPool,
          _links,
        );
      },
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUnixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException("[server] out of memory");
        }
        final result = _bindings.transport_server_initialize_unix_dgram(
          pointer,
          _unixDatagramConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descritor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException("[server] code = $result, message = ${result.kernelErrorToString(_bindings)}");
          }
          throw TransportInitializationException("[server] unable to set socket option: ${-result}");
        }
        return TransportServer(
          pointer,
          _workerPointer,
          _bindings,
          _callbacks,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
          _buffers,
          this,
          _payloadPool,
          _links,
        );
      },
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  @pragma(preferInlinePragma)
  TransportServer getByServer(int fd) => _servers[fd]!;

  @pragma(preferInlinePragma)
  TransportServer getByConnection(int fd) => _serverConnections[fd]!;

  @pragma(preferInlinePragma)
  void addConnection(int serverFd, int connectionFd) => _serverConnections[connectionFd] = _servers[serverFd]!;

  @pragma(preferInlinePragma)
  void removeConnection(int fd) => _serverConnections.remove(fd);

  @pragma(preferInlinePragma)
  void removeServer(int fd) => _servers.remove(fd);

  Future<void> close({Duration? gracefulDuration}) => Future.wait(_servers.values.toList().map((server) => server.close(gracefulDuration: gracefulDuration)));

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
    if (serverConfiguration.tcpNoDelay == true) flags |= transportSocketOptionTcpNoDelay;
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
        interface.getMembershipIndex(_bindings),
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
