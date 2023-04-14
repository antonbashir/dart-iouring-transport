import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'channels.dart';
import 'communicator.dart';
import 'configuration.dart';
import 'constants.dart';
import 'defaults.dart';
import 'callbacks.dart';
import 'exception.dart';
import 'payload.dart';

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int readTimeout;
  final int writeTimeout;
  final Transportcallbacks callbacks;
  final Queue<Completer<int>> _bufferFinalizers;
  final TransportServerRegistry _registry;

  late final int fd;
  late final Pointer<iovec> _buffers;

  var _active = true;
  bool get active => _active;
  final _closer = Completer();

  var _pending = 0;

  TransportServer(
    this.pointer,
    this._workerPointer,
    this._bindings,
    this.callbacks,
    this.readTimeout,
    this.writeTimeout,
    this._bufferFinalizers,
    this._registry,
  ) {
    fd = pointer.ref.fd;
    _buffers = _workerPointer.ref.buffers;
  }

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection communicator) onAccept) {
    callbacks.setAccept(fd, (channel) => onAccept(TransportServerConnection(this, channel)));
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  @pragma(preferInlinePragma)
  void reaccept() {
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  Future<TransportInboundStreamPayload> read(TransportChannel channel) async {
    final bufferId = channel.getBuffer() ?? await channel.allocate();
    if (!active) throw TransportClosedException.forServer();
    if (!hasConnection(channel.fd)) throw TransportClosedException.forConnection();
    final completer = Completer<void>();
    callbacks.setInboundRead(bufferId, completer);
    channel.read(bufferId, readTimeout, transportEventRead);
    _pending++;
    return completer.future.then(
      (_) => TransportInboundStreamPayload(
        readBuffer(bufferId),
        () => releaseBuffer(bufferId),
        (bytes) {
          if (!active) throw TransportClosedException.forServer();
          reuseBuffer(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
          _pending++;
          return completer.future;
        },
      ),
    );
  }

  Future<void> write(Uint8List bytes, TransportChannel channel) async {
    final bufferId = channel.getBuffer() ?? await channel.allocate();
    if (!active) throw TransportClosedException.forServer();
    if (!hasConnection(channel.fd)) throw TransportClosedException.forConnection();
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
    _pending++;
    return completer.future;
  }

  Future<TransportInboundDatagramPayload> receiveMessage(TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = channel.getBuffer() ?? await channel.allocate();
    if (!active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    callbacks.setInboundRead(bufferId, completer);
    channel.receiveMessage(bufferId, pointer.ref.family, readTimeout, flags, transportEventReceiveMessage);
    _pending++;
    return completer.future.then(
      (_) => TransportInboundDatagramPayload(
        readBuffer(bufferId),
        TransportInboundDatagramSender(
          this,
          channel,
          bufferId,
          readBuffer(bufferId),
        ),
        () => releaseBuffer(bufferId),
        (bytes, flags) {
          if (!active) throw TransportClosedException.forServer();
          reuseBuffer(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.respondMessage(bytes, bufferId, pointer.ref.family, writeTimeout, flags, transportEventSendMessage);
          _pending++;
          return completer.future;
        },
      ),
    );
  }

  Future<void> sendMessage(Uint8List bytes, int senderInitalBufferId, TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (!active) throw TransportClosedException.forServer();
    final bufferId = channel.getBuffer() ?? await channel.allocate();
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      _bindings.transport_worker_get_endpoint_address(_workerPointer, pointer.ref.family, senderInitalBufferId),
      writeTimeout,
      flags,
      transportEventSendMessage,
    );
    _pending++;
    return completer.future;
  }

  @pragma(preferInlinePragma)
  void releaseBuffer(int bufferId) {
    if (!active) throw TransportClosedException.forServer();
    _bindings.transport_worker_release_buffer(_workerPointer, bufferId);
    if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
  }

  @pragma(preferInlinePragma)
  void reuseBuffer(int bufferId) {
    if (!active) throw TransportClosedException.forServer();
    _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
    if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
  }

  @pragma(preferInlinePragma)
  Uint8List readBuffer(int bufferId) {
    final buffer = _buffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    return bufferBytes.asTypedList(buffer.iov_len);
  }

  @pragma(preferInlinePragma)
  void onComplete() {
    _pending--;
    if (!_active && _pending == 0) _closer.complete();
  }

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0;

  @pragma(preferInlinePragma)
  bool hasConnection(int fd) => _registry._serversByClients.containsKey(fd);

  Future<void> close() async {
    if (_active) {
      _active = false;
      _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
      _registry._serversByClients.forEach((key, value) {
        if (value.fd == fd) _bindings.transport_worker_cancel_by_fd(_workerPointer, key);
      });
      if (_pending > 0) await _closer.future;
      _bindings.transport_close_descritor(pointer.ref.fd);
      _bindings.transport_server_destroy(pointer);
    }
  }

  void closeConnection(TransportChannel channel) {
    if (!_active) throw TransportClosedException.forServer();
    if (!hasConnection(channel.fd)) return;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, channel.fd);
  }
}

class TransportServerRegistry {
  final _servers = <int, TransportServer>{};
  final _serversByClients = <int, TransportServer>{};

  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final Transportcallbacks _callbacks;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportServerRegistry(this._bindings, this._callbacks, this._workerPointer, this._bufferFinalizers);

  TransportServer createTcp(String host, int port, {TransportTcpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.tcpServer();
    final server = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_tcp(
          _tcpConfiguration(configuration!, arena),
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ),
        _workerPointer,
        _bindings,
        _callbacks,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
        _bufferFinalizers,
        this,
      ),
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUdp(String host, int port, {TransportUdpServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpServer();
    final server = using(
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
          _callbacks,
          configuration.readTimeout.inSeconds,
          configuration.writeTimeout.inSeconds,
          _bufferFinalizers,
          this,
        );
      },
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUnixStream(String path, {TransportUnixStreamServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixStreamServer();
    final server = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_stream(
          _unixStreamConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _workerPointer,
        _bindings,
        _callbacks,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
        _bufferFinalizers,
        this,
      ),
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  TransportServer createUnixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramServer();
    final server = using(
      (Arena arena) => TransportServer(
        _bindings.transport_server_initialize_unix_dgram(
          _unixDatagramConfiguration(configuration!, arena),
          path.toNativeUtf8(allocator: arena).cast(),
        ),
        _workerPointer,
        _bindings,
        _callbacks,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
        _bufferFinalizers,
        this,
      ),
    );
    _servers[server.pointer.ref.fd] = server;
    return server;
  }

  @pragma(preferInlinePragma)
  TransportServer getByServer(int fd) => _servers[fd]!;

  @pragma(preferInlinePragma)
  TransportServer? getByClient(int fd) => _serversByClients[fd];

  @pragma(preferInlinePragma)
  void addClient(int serverFd, int clientFd) => _serversByClients[clientFd] = _servers[serverFd]!;

  @pragma(preferInlinePragma)
  void removeClient(int fd) => _serversByClients.remove(fd);

  @pragma(preferInlinePragma)
  void removeServer(int fd) {
    _servers.remove(fd);
    _serversByClients.removeWhere((key, value) => value.fd == fd);
  }

  Future<void> close() => Future.wait(_servers.values.map((server) => server.close()));

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
