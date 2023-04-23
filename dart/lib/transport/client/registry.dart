import 'dart:ffi';

import 'package:ffi/ffi.dart';
import '../links.dart';
import '../payload.dart';
import '../exception.dart';
import '../extensions.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../defaults.dart';
import 'client.dart';
import 'communicator.dart';
import 'configuration.dart';

class TransportClientRegistry {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;

  final _clients = <int, TransportClient>{};

  TransportClientRegistry(this._bindings, this._callbacks, this._workerPointer, this._buffers, this._payloadPool, this._links);

  Future<TransportClientStreamCommunicators> createTcp(String host, int port, {TransportTcpClientConfiguration? configuration}) async {
    final communicators = <Future<TransportClientStreamCommunicator>>[];
    configuration = configuration ?? TransportDefaults.tcpClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = calloc<transport_client_t>();
      if (clientPointer == nullptr) {
        throw TransportInitializationException("[client] out of memory");
      }
      final result = using(
        (arena) => _bindings.transport_client_initialize_tcp(
          clientPointer,
          _tcpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
      );
      if (result < 0) {
        if (clientPointer.ref.fd > 0) {
          _bindings.transport_close_descritor(clientPointer.ref.fd);
          calloc.free(clientPointer);
          throw TransportInitializationException("[client] code = $result, message = ${result.kernelErrorToString(_bindings)}");
        }
        throw TransportInitializationException("[client] unable to set socket option: ${-result}");
      }
      final client = TransportClient(
        _callbacks,
        _links,
        TransportChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _buffers,
        ),
        clientPointer,
        _workerPointer,
        _bindings,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
        _buffers,
        this,
        _payloadPool,
        connectTimeout: configuration.connectTimeout.inSeconds,
      );
      _clients[clientPointer.ref.fd] = client;
      communicators.add(client.connect().then((client) => TransportClientStreamCommunicator(client)));
    }
    return TransportClientStreamCommunicators(await Future.wait(communicators));
  }

  Future<TransportClientStreamCommunicators> createUnixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) async {
    final clients = <Future<TransportClientStreamCommunicator>>[];
    configuration = configuration ?? TransportDefaults.unixStreamClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = calloc<transport_client_t>();
      if (clientPointer == nullptr) {
        throw TransportInitializationException("[client] out of memory");
      }
      final result = using(
        (arena) => _bindings.transport_client_initialize_unix_stream(
          clientPointer,
          _unixStreamConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
      );
      if (result < 0) {
        if (clientPointer.ref.fd > 0) {
          _bindings.transport_close_descritor(clientPointer.ref.fd);
          calloc.free(clientPointer);
          throw TransportInitializationException("[client] code = $result, message = ${result.kernelErrorToString(_bindings)}");
        }
        throw TransportInitializationException("[client] unable to set socket option: ${-result}");
      }
      final client = TransportClient(
        _callbacks,
        _links,
        TransportChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _buffers,
        ),
        clientPointer,
        _workerPointer,
        _bindings,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
        _buffers,
        this,
        _payloadPool,
        connectTimeout: configuration.connectTimeout.inSeconds,
      );
      _clients[clientPointer.ref.fd] = client;
      clients.add(client.connect().then((client) => TransportClientStreamCommunicator(client)));
    }
    return TransportClientStreamCommunicators(await Future.wait(clients));
  }

  TransportClientDatagramCommunicator createUdp(String sourceHost, int sourcePort, String destinationHost, int destinationPort, {TransportUdpClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpClient();
    final clientPointer = using((arena) {
      final pointer = calloc<transport_client_t>();
      if (pointer == nullptr) {
        throw TransportInitializationException("[client] out of memory");
      }
      final result = _bindings.transport_client_initialize_udp(
        pointer,
        _udpConfiguration(configuration!, arena),
        destinationHost.toNativeUtf8(allocator: arena).cast(),
        destinationPort,
        sourceHost.toNativeUtf8(allocator: arena).cast(),
        sourcePort,
      );
      if (result < 0) {
        if (pointer.ref.fd > 0) {
          _bindings.transport_close_descritor(pointer.ref.fd);
          calloc.free(pointer);
          throw TransportInitializationException("[client] code = $result, message = ${result.kernelErrorToString(_bindings)}");
        }
        throw TransportInitializationException("[client] unable to set socket option: ${-result}");
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
      return pointer;
    });
    final client = TransportClient(
      _callbacks,
      _links,
      TransportChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _buffers,
      ),
      clientPointer,
      _workerPointer,
      _bindings,
      configuration.readTimeout.inSeconds,
      configuration.writeTimeout.inSeconds,
      _buffers,
      this,
      _payloadPool,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportClientDatagramCommunicator(client);
  }

  TransportClientDatagramCommunicator createUnixDatagram(String sourcePath, String destinationPath, {TransportUnixDatagramClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramClient();
    final clientPointer = calloc<transport_client_t>();
    if (clientPointer == nullptr) {
      throw TransportInitializationException("[client] out of memory");
    }
    final result = using(
      (arena) => _bindings.transport_client_initialize_unix_dgram(
        clientPointer,
        _unixDatagramConfiguration(configuration!, arena),
        destinationPath.toNativeUtf8(allocator: arena).cast(),
        sourcePath.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    if (result < 0) {
      if (clientPointer.ref.fd > 0) {
        _bindings.transport_close_descritor(clientPointer.ref.fd);
        calloc.free(clientPointer);
        throw TransportInitializationException("[client] code = $result, message = ${result.kernelErrorToString(_bindings)}");
      }
      throw TransportInitializationException("[client] unable to set socket option: ${-result}");
    }
    final client = TransportClient(
      _callbacks,
      _links,
      TransportChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _buffers,
      ),
      clientPointer,
      _workerPointer,
      _bindings,
      configuration.readTimeout.inSeconds,
      configuration.writeTimeout.inSeconds,
      _buffers,
      this,
      _payloadPool,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportClientDatagramCommunicator(client);
  }

  TransportClient get(int fd) => _clients[fd]!;

  Future<void> close() async {
    await Future.wait(_clients.values.map((client) => client.close()));
    _clients.clear();
  }

  void removeClient(int fd) => _clients.remove(fd);

  Pointer<transport_client_configuration_t> _tcpConfiguration(TransportTcpClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    int flags = 0;
    if (clientConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (clientConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (clientConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (clientConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (clientConfiguration.socketKeepalive == true) flags |= transportSocketOptionSocketKeepalive;
    if (clientConfiguration.ipFreebind == true) flags |= transportSocketOptionIpFreebind;
    if (clientConfiguration.tcpQuickack == true) flags |= transportSocketOptionTcpQuickack;
    if (clientConfiguration.tcpDeferAccept == true) flags |= transportSocketOptionTcpDeferAccept;
    if (clientConfiguration.tcpFastopen == true) flags |= transportSocketOptionTcpFastopen;
    if (clientConfiguration.tcpNodelay == true) flags |= transportSocketOptionTcpNodelay;
    if (clientConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeClientConfiguration.ref.socket_receive_buffer_size = clientConfiguration.socketReceiveBufferSize!;
    }
    if (clientConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeClientConfiguration.ref.socket_send_buffer_size = clientConfiguration.socketSendBufferSize!;
    }
    if (clientConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeClientConfiguration.ref.socket_receive_low_at = clientConfiguration.socketReceiveLowAt!;
    }
    if (clientConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeClientConfiguration.ref.socket_send_low_at = clientConfiguration.socketSendLowAt!;
    }
    if (clientConfiguration.ipTtl != null) {
      flags |= transportSocketOptionIpTtl;
      nativeClientConfiguration.ref.ip_ttl = clientConfiguration.ipTtl!;
    }
    if (clientConfiguration.tcpKeepAliveIdle != null) {
      flags |= transportSocketOptionTcpKeepidle;
      nativeClientConfiguration.ref.tcp_keep_alive_idle = clientConfiguration.tcpKeepAliveIdle!;
    }
    if (clientConfiguration.tcpKeepAliveMaxCount != null) {
      flags |= transportSocketOptionTcpKeepcnt;
      nativeClientConfiguration.ref.tcp_keep_alive_max_count = clientConfiguration.tcpKeepAliveMaxCount!;
    }
    if (clientConfiguration.tcpKeepAliveIdle != null) {
      flags |= transportSocketOptionTcpKeepintvl;
      nativeClientConfiguration.ref.tcp_keep_alive_individual_count = clientConfiguration.tcpKeepAliveIdle!;
    }
    if (clientConfiguration.tcpMaxSegmentSize != null) {
      flags |= transportSocketOptionTcpMaxseg;
      nativeClientConfiguration.ref.tcp_max_segment_size = clientConfiguration.tcpMaxSegmentSize!;
    }
    if (clientConfiguration.tcpSynCount != null) {
      flags |= transportSocketOptionTcpSyncnt;
      nativeClientConfiguration.ref.tcp_syn_count = clientConfiguration.tcpSynCount!;
    }
    nativeClientConfiguration.ref.socket_configuration_flags = flags;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _udpConfiguration(TransportUdpClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    int flags = 0;
    if (clientConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (clientConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (clientConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (clientConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
    if (clientConfiguration.socketBroadcast == true) flags |= transportSocketOptionSocketBroadcast;
    if (clientConfiguration.ipFreebind == true) flags |= transportSocketOptionIpFreebind;
    if (clientConfiguration.ipMulticastAll == true) flags |= transportSocketOptionIpMulticastAll;
    if (clientConfiguration.ipMulticastLoop == true) flags |= transportSocketOptionIpMulticastLoop;
    if (clientConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeClientConfiguration.ref.socket_receive_buffer_size = clientConfiguration.socketReceiveBufferSize!;
    }
    if (clientConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeClientConfiguration.ref.socket_send_buffer_size = clientConfiguration.socketSendBufferSize!;
    }
    if (clientConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeClientConfiguration.ref.socket_receive_low_at = clientConfiguration.socketReceiveLowAt!;
    }
    if (clientConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeClientConfiguration.ref.socket_send_low_at = clientConfiguration.socketSendLowAt!;
    }
    if (clientConfiguration.ipTtl != null) {
      flags |= transportSocketOptionIpTtl;
      nativeClientConfiguration.ref.ip_ttl = clientConfiguration.ipTtl!;
    }
    if (clientConfiguration.ipMulticastTtl != null) {
      flags |= transportSocketOptionIpMulticastTtl;
      nativeClientConfiguration.ref.ip_multicast_ttl = clientConfiguration.ipMulticastTtl!;
    }
    if (clientConfiguration.ipMulticastInterface != null) {
      flags |= transportSocketOptionIpMulticastIf;
      final interface = clientConfiguration.ipMulticastInterface!;
      nativeClientConfiguration.ref.ip_multicast_interface = _bindings.transport_socket_multicast_create_request(
        interface.groupAddress.toNativeUtf8(allocator: allocator).cast(),
        interface.localAddress.toNativeUtf8(allocator: allocator).cast(),
        interface.getMembershipIndex(_bindings),
      );
    }
    nativeClientConfiguration.ref.socket_configuration_flags = flags;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _unixStreamConfiguration(TransportUnixStreamClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    int flags = 0;
    if (clientConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (clientConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (clientConfiguration.socketKeepalive == true) flags |= transportSocketOptionSocketKeepalive;
    if (clientConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeClientConfiguration.ref.socket_receive_buffer_size = clientConfiguration.socketReceiveBufferSize!;
    }
    if (clientConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeClientConfiguration.ref.socket_send_buffer_size = clientConfiguration.socketSendBufferSize!;
    }
    if (clientConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeClientConfiguration.ref.socket_receive_low_at = clientConfiguration.socketReceiveLowAt!;
    }
    if (clientConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeClientConfiguration.ref.socket_send_low_at = clientConfiguration.socketSendLowAt!;
    }
    nativeClientConfiguration.ref.socket_configuration_flags = flags;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _unixDatagramConfiguration(TransportUnixDatagramClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    int flags = 0;
    if (clientConfiguration.socketNonblock == true) flags |= transportSocketOptionSocketNonblock;
    if (clientConfiguration.socketClockexec == true) flags |= transportSocketOptionSocketClockexec;
    if (clientConfiguration.socketReceiveBufferSize != null) {
      flags |= transportSocketOptionSocketRcvbuf;
      nativeClientConfiguration.ref.socket_receive_buffer_size = clientConfiguration.socketReceiveBufferSize!;
    }
    if (clientConfiguration.socketSendBufferSize != null) {
      flags |= transportSocketOptionSocketSndbuf;
      nativeClientConfiguration.ref.socket_send_buffer_size = clientConfiguration.socketSendBufferSize!;
    }
    if (clientConfiguration.socketReceiveLowAt != null) {
      flags |= transportSocketOptionSocketRcvlowat;
      nativeClientConfiguration.ref.socket_receive_low_at = clientConfiguration.socketReceiveLowAt!;
    }
    if (clientConfiguration.socketSendLowAt != null) {
      flags |= transportSocketOptionSocketSndlowat;
      nativeClientConfiguration.ref.socket_send_low_at = clientConfiguration.socketSendLowAt!;
    }
    nativeClientConfiguration.ref.socket_configuration_flags = flags;
    return nativeClientConfiguration;
  }
}
