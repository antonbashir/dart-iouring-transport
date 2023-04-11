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
import 'exception.dart';
import 'payload.dart';
import 'state.dart';

class TransportClient {
  final TransportEventStates _eventStates;
  final Pointer<transport_client_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportChannel _channel;
  final TransportBindings _bindings;
  final int? connectTimeout;
  final int readTimeout;
  final int writeTimeout;

  var _active = true;
  bool get active => _active;
  final _closer = Completer();

  var _pending = 0;

  TransportClient._(
    this._eventStates,
    this._channel,
    this.pointer,
    this._workerPointer,
    this._bindings,
    this.connectTimeout,
    this.readTimeout,
    this.writeTimeout,
  );

  factory TransportClient.withConnection(
    TransportEventStates _eventStates,
    TransportChannel _channel,
    Pointer<transport_client_t> pointer,
    Pointer<transport_worker_t> _workerPointer,
    TransportBindings _bindings,
    int connectTimeout,
    int readTimeout,
    int writeTimeout,
  ) =>
      TransportClient._(
        _eventStates,
        _channel,
        pointer,
        _workerPointer,
        _bindings,
        connectTimeout,
        readTimeout,
        writeTimeout,
      );

  factory TransportClient.withoutConnection(
    TransportEventStates _eventStates,
    TransportChannel _channel,
    Pointer<transport_client_t> pointer,
    Pointer<transport_worker_t> _workerPointer,
    TransportBindings _bindings,
    int readTimeout,
    int writeTimeout,
  ) =>
      TransportClient._(
        _eventStates,
        _channel,
        pointer,
        _workerPointer,
        _bindings,
        null,
        readTimeout,
        writeTimeout,
      );

  Future<TransportOutboundPayload> read() async {
    final bufferId = await _channel.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<TransportOutboundPayload>();
    _eventStates.setOutboundRead(bufferId, completer);
    _channel.read(bufferId, readTimeout, offset: 0);
    _pending++;
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = await _channel.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _eventStates.setOutboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, writeTimeout);
    _pending++;
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = await _channel.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<TransportOutboundPayload>();
    _eventStates.setOutboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, pointer.ref.family, readTimeout, flags);
    _pending++;
    return completer.future;
  }

  Future<void> sendMessage(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = await _channel.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _eventStates.setOutboundWrite(bufferId, completer);
    _channel.sendMessage(bytes, bufferId, pointer.ref.family, _bindings.transport_client_get_destination_address(pointer), writeTimeout, flags);
    _pending++;
    return completer.future;
  }

  Future<TransportClient> connect(Pointer<transport_worker_t> workerPointer) {
    final completer = Completer<TransportClient>();
    _eventStates.setConnect(pointer.ref.fd, completer);
    _bindings.transport_worker_connect(workerPointer, pointer, connectTimeout!);
    _pending++;
    return completer.future;
  }

  @pragma(preferInlinePragma)
  void onComplete() {
    _pending--;
    if (!_active && _pending == 0) _closer.complete();
  }

  Future<void> close() async {
    if (_active) {
      _active = false;
      _bindings.transport_worker_cancel(_workerPointer);
      if (_pending > 0) await _closer.future;
      _channel.close();
      _bindings.transport_client_destroy(pointer);
    }
  }
}

class TransportClientCommunicators {
  final List<TransportClientCommunicator> _communicators;
  var _next = 0;

  TransportClientCommunicators(this._communicators);

  TransportClientCommunicator select() {
    final client = _communicators[_next];
    if (++_next == _communicators.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportClientCommunicator communicator) action) => _communicators.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportClientCommunicator communicator) mapper) => _communicators.map(mapper);
}

class TransportClientRegistry {
  final TransportBindings _bindings;
  final TransportEventStates _eventStates;
  final Pointer<transport_worker_t> _workerPointer;
  final Queue<Completer<int>> _bufferFinalizers;
  final _clients = <int, TransportClient>{};

  TransportClientRegistry(this._eventStates, this._workerPointer, this._bindings, this._bufferFinalizers);

  Future<TransportClientCommunicators> createTcp(String host, int port, {TransportTcpClientConfiguration? configuration}) async {
    final communicators = <Future<TransportClientCommunicator>>[];
    configuration = configuration ?? TransportDefaults.tcpClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = using((arena) => _bindings.transport_client_initialize_tcp(
            _tcpConfiguration(configuration!, arena),
            host.toNativeUtf8(allocator: arena).cast(),
            port,
          ));
      final client = TransportClient.withConnection(
        _eventStates,
        TransportChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _bufferFinalizers,
        ),
        clientPointer,
        _workerPointer,
        _bindings,
        configuration.connectTimeout.inSeconds,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
      );
      _clients[clientPointer.ref.fd] = client;
      communicators.add(client.connect(_workerPointer).then((client) => TransportClientCommunicator(client)));
    }
    return TransportClientCommunicators(await Future.wait(communicators));
  }

  Future<TransportClientCommunicators> createUnixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) async {
    final clients = <Future<TransportClientCommunicator>>[];
    configuration = configuration ?? TransportDefaults.unixStreamClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = using((arena) => _bindings.transport_client_initialize_unix_stream(
            _unixStreamConfiguration(configuration!, arena),
            path.toNativeUtf8(allocator: arena).cast(),
          ));
      final clinet = TransportClient.withConnection(
        _eventStates,
        TransportChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _bufferFinalizers,
        ),
        clientPointer,
        _workerPointer,
        _bindings,
        configuration.connectTimeout.inSeconds,
        configuration.readTimeout.inSeconds,
        configuration.writeTimeout.inSeconds,
      );
      _clients[clientPointer.ref.fd] = clinet;
      clients.add(clinet.connect(_workerPointer).then((client) => TransportClientCommunicator(client)));
    }
    return TransportClientCommunicators(await Future.wait(clients));
  }

  TransportClientCommunicator createUdp(String sourceHost, int sourcePort, String destinationHost, int destinationPort, {TransportUdpClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpClient();
    final clientPointer = using((arena) {
      final pointer = _bindings.transport_client_initialize_udp(
        _udpConfiguration(configuration!, arena),
        destinationHost.toNativeUtf8(allocator: arena).cast(),
        destinationPort,
        sourceHost.toNativeUtf8(allocator: arena).cast(),
        sourcePort,
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
      return pointer;
    });
    final client = TransportClient.withoutConnection(
      _eventStates,
      TransportChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
      clientPointer,
      _workerPointer,
      _bindings,
      configuration.readTimeout.inSeconds,
      configuration.writeTimeout.inSeconds,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportClientCommunicator(client);
  }

  TransportClientCommunicator createUnixDatagram(String sourcePath, String destinationPath, {TransportUnixDatagramClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramClient();
    final clientPointer = using(
      (arena) => _bindings.transport_client_initialize_unix_dgram(
        _unixDatagramConfiguration(configuration!, arena),
        destinationPath.toNativeUtf8(allocator: arena).cast(),
        sourcePath.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    final client = TransportClient.withoutConnection(
      _eventStates,
      TransportChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
      clientPointer,
      _workerPointer,
      _bindings,
      configuration.readTimeout.inSeconds,
      configuration.writeTimeout.inSeconds,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportClientCommunicator(client);
  }

  TransportClient? get(int fd) => _clients[fd];

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
        interface.getMemberShipIndex(_bindings),
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
    if (clientConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (clientConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
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
    if (clientConfiguration.socketReuseAddress == true) flags |= transportSocketOptionSocketReuseaddr;
    if (clientConfiguration.socketReusePort == true) flags |= transportSocketOptionSocketReuseport;
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
