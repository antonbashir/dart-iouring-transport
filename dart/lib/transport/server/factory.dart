import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../configuration.dart';
import '../constants.dart';
import '../defaults.dart';
import '../exception.dart';
import '../payload.dart';
import 'configuration.dart';
import 'provider.dart';
import 'registry.dart';
import 'responder.dart';
import 'server.dart';

class TransportServersFactory {
  final TransportServerRegistry _registry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;
  final TransportServerDatagramResponderPool _datagramResponderPool;

  const TransportServersFactory(
    this._registry,
    this._bindings,
    this._workerPointer,
    this._buffers,
    this._payloadPool,
    this._datagramResponderPool,
  );

  TransportServer tcp(
    InternetAddress address,
    int port,
    void Function(TransportServerConnection connection) onAccept, {
    TransportTcpServerConfiguration? configuration,
  }) {
    configuration = configuration ?? TransportDefaults.tcpServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException(TransportMessages.serverMemoryError);
        }
        final result = _bindings.transport_server_initialize_tcp(
          pointer,
          _tcpConfiguration(configuration!, arena),
          address.address.toNativeUtf8(allocator: arena).cast(),
          port,
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descriptor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException(TransportMessages.serverError(result, _bindings));
          }
          calloc.free(pointer);
          throw TransportInitializationException(TransportMessages.serverSocketError(result));
        }
        return TransportServerChannel(
          pointer,
          _workerPointer,
          _bindings,
          configuration.readTimeout?.inSeconds,
          configuration.writeTimeout?.inSeconds,
          _buffers,
          _registry,
          _payloadPool,
          _datagramResponderPool,
        );
      },
    );
    _registry.addServer(server.pointer.ref.fd, server);
    return server..accept(onAccept);
  }

  TransportServerDatagramReceiver udp(
    InternetAddress address,
    int port, {
    TransportUdpServerConfiguration? configuration,
  }) {
    configuration = configuration ?? TransportDefaults.udpServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException(TransportMessages.serverMemoryError);
        }
        final result = _bindings.transport_server_initialize_udp(
          pointer,
          _udpConfiguration(configuration!, arena),
          address.address.toNativeUtf8(allocator: arena).cast(),
          port,
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descriptor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException(TransportMessages.serverError(result, _bindings));
          }
          calloc.free(pointer);
          throw TransportInitializationException(TransportMessages.serverSocketError(result));
        }
        if (configuration.multicastManager != null) {
          configuration.multicastManager!.subscribe(
            onAddMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_add_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                _getMembershipIndex(configuration),
              ),
            ),
            onDropMembership: (configuration) => using(
              (arena) => _bindings.transport_socket_multicast_drop_membership(
                pointer.ref.fd,
                configuration.groupAddress.toNativeUtf8(allocator: arena).cast(),
                configuration.localAddress.toNativeUtf8(allocator: arena).cast(),
                _getMembershipIndex(configuration),
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
        return TransportServerChannel(
          pointer,
          _workerPointer,
          _bindings,
          configuration.readTimeout?.inSeconds,
          configuration.writeTimeout?.inSeconds,
          _buffers,
          _registry,
          _payloadPool,
          _datagramResponderPool,
          datagramChannel: TransportChannel(
            _workerPointer,
            pointer.ref.fd,
            _bindings,
            _buffers,
          ),
        );
      },
    );
    _registry.addServer(server.pointer.ref.fd, server);
    return TransportServerDatagramReceiver(server);
  }

  TransportServer unixStream(
    String path,
    void Function(TransportServerConnection connection) onAccept, {
    TransportUnixStreamServerConfiguration? configuration,
  }) {
    configuration = configuration ?? TransportDefaults.unixStreamServer();
    final server = using(
      (Arena arena) {
        final pointer = calloc<transport_server_t>();
        if (pointer == nullptr) {
          throw TransportInitializationException(TransportMessages.serverMemoryError);
        }
        final result = _bindings.transport_server_initialize_unix_stream(
          pointer,
          _unixStreamConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        );
        if (result < 0) {
          if (pointer.ref.fd > 0) {
            _bindings.transport_close_descriptor(pointer.ref.fd);
            calloc.free(pointer);
            throw TransportInitializationException(TransportMessages.serverError(result, _bindings));
          }
          calloc.free(pointer);
          throw TransportInitializationException(TransportMessages.serverSocketError(result));
        }
        return TransportServerChannel(
          pointer,
          _workerPointer,
          _bindings,
          configuration.readTimeout?.inSeconds,
          configuration.writeTimeout?.inSeconds,
          _buffers,
          _registry,
          _payloadPool,
          _datagramResponderPool,
        );
      },
    );
    _registry.addServer(server.pointer.ref.fd, server);
    return server..accept(onAccept);
  }

  Pointer<transport_server_configuration_t> _tcpConfiguration(TransportTcpServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    var flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketCloexec == true) flags |= transportSocketOptionSocketCloexec;
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
    var flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketCloexec == true) flags |= transportSocketOptionSocketCloexec;
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
      nativeServerConfiguration.ref.ip_multicast_interface = allocator<ip_mreqn>();
      _bindings.transport_socket_initialize_multicast_request(
        nativeServerConfiguration.ref.ip_multicast_interface,
        interface.groupAddress.toNativeUtf8(allocator: allocator).cast(),
        interface.localAddress.toNativeUtf8(allocator: allocator).cast(),
        _getMembershipIndex(interface),
      );
    }
    nativeServerConfiguration.ref.socket_configuration_flags = flags;
    return nativeServerConfiguration;
  }

  Pointer<transport_server_configuration_t> _unixStreamConfiguration(TransportUnixStreamServerConfiguration serverConfiguration, Allocator allocator) {
    final nativeServerConfiguration = allocator<transport_server_configuration_t>();
    var flags = 0;
    if (serverConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (serverConfiguration.socketCloexec == true) flags |= transportSocketOptionSocketCloexec;
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

  int _getMembershipIndex(TransportUdpMulticastConfiguration configuration) => using(
        (arena) {
          if (configuration.calculateInterfaceIndex) {
            return _bindings.transport_socket_get_interface_index(configuration.localInterface!.toNativeUtf8(allocator: arena).cast());
          }
          return configuration.interfaceIndex!;
        },
      );

  @visibleForTesting
  TransportServerRegistry get registry => _registry;
}
