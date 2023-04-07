import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'configuration.dart';
import 'defaults.dart';
import 'exception.dart';
import 'payload.dart';

class TransportCommunicator {
  final TransportClient _client;

  TransportCommunicator(this._client);

  Future<TransportOutboundPayload> read() => _client.read();

  Future<void> write(Uint8List bytes) => _client.write(bytes);

  Future<TransportOutboundPayload> receiveMessage() => _client.receiveMessage();

  Future<void> sendMessage(Uint8List bytes) => _client.sendMessage(bytes);

  void close() => _client.close();
}

class TransportClient {
  final TransportCallbacks _callbacks;
  final Pointer<transport_client_t> pointer;
  final TransportOutboundChannel _channel;

  var _active = true;
  bool get active => _active;

  TransportClient(this._callbacks, this._channel, this.pointer);

  Future<TransportOutboundPayload> read() async {
    if (!_active) throw TransportClosedException.forClient();
    final bufferId = await _channel.allocate();
    final completer = Completer<TransportOutboundPayload>();
    _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, offset: 0);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    if (!_active) throw TransportClosedException.forClient();
    final bufferId = await _channel.allocate();
    final completer = Completer<void>();
    _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId);
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessage() async {
    if (!_active) throw TransportClosedException.forClient();
    final bufferId = await _channel.allocate();
    final completer = Completer<TransportOutboundPayload>();
    _callbacks.putRead(bufferId, completer);
    _channel.receiveMessage(bufferId, pointer);
    return completer.future;
  }

  Future<void> sendMessage(Uint8List bytes) async {
    if (!_active) throw TransportClosedException.forClient();
    final bufferId = await _channel.allocate();
    final completer = Completer<void>();
    _callbacks.putWrite(bufferId, completer);
    _channel.sendMessage(bytes, bufferId, pointer);
    return completer.future;
  }

  void close() {
    if (_active) {
      _channel.close();
      _active = false;
    }
  }
}

class TransportCommunicators {
  final List<TransportCommunicator> _communicators;
  var _next = 0;

  TransportCommunicators(this._communicators);

  TransportCommunicator select() {
    final client = _communicators[_next];
    if (++_next == _communicators.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportCommunicator communicator) action) => _communicators.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportCommunicator communicator) mapper) => _communicators.map(mapper);
}

class TransportClientRegistry {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final Queue<Completer<int>> _bufferFinalizers;
  final _clients = <int, TransportClient>{};

  TransportClientRegistry(this._callbacks, this._workerPointer, this._bindings, this._bufferFinalizers);

  Future<TransportCommunicators> createTcp(String host, int port, {TransportTcpClientConfiguration? configuration}) async {
    final communicators = <Future<TransportCommunicator>>[];
    configuration = configuration ?? TransportDefaults.tcpClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = using((arena) => _bindings.transport_client_initialize_tcp(
            _tcpConfiguration(configuration!, arena),
            host.toNativeUtf8(allocator: arena).cast(),
            port,
          ));
      _clients[clientPointer.ref.fd] = TransportClient(
        _callbacks,
        TransportOutboundChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _bufferFinalizers,
        ),
        clientPointer,
      );
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(clientPointer.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, clientPointer);
      communicators.add(completer.future.then((client) => TransportCommunicator(client)));
    }
    return TransportCommunicators(await Future.wait(communicators));
  }

  Future<TransportCommunicators> createUnixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) async {
    final clients = <Future<TransportCommunicator>>[];
    configuration = configuration ?? TransportDefaults.unixStreamClient();
    for (var clientIndex = 0; clientIndex < configuration.pool; clientIndex++) {
      final clientPointer = using((arena) => _bindings.transport_client_initialize_unix_stream(
            _unixStreamConfiguration(configuration!, arena),
            path.toNativeUtf8(allocator: arena).cast(),
          ));
      _clients[clientPointer.ref.fd] = TransportClient(
        _callbacks,
        TransportOutboundChannel(
          _workerPointer,
          clientPointer.ref.fd,
          _bindings,
          _bufferFinalizers,
        ),
        clientPointer,
      );
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(clientPointer.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, clientPointer);
      clients.add(completer.future.then((client) => TransportCommunicator(client)));
    }
    return TransportCommunicators(await Future.wait(clients));
  }

  TransportCommunicator createUdp(String sourceHost, int sourcePort, String destinationHost, int destinationPort, {TransportUdpClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.udpClient();
    final clientPointer = using(
      (arena) => _bindings.transport_client_initialize_udp(
        _udpConfiguration(configuration!, arena),
        destinationHost.toNativeUtf8(allocator: arena).cast(),
        destinationPort,
        sourceHost.toNativeUtf8(allocator: arena).cast(),
        sourcePort,
      ),
    );
    final client = TransportClient(
      _callbacks,
      TransportOutboundChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
      clientPointer,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportCommunicator(client);
  }

  TransportCommunicator createUnixDatagram(String sourcePath, String destinationPath, {TransportUnixDatagramClientConfiguration? configuration}) {
    configuration = configuration ?? TransportDefaults.unixDatagramClient();
    final clientPointer = using(
      (arena) => _bindings.transport_client_initialize_unix_dgram(
        _unixDatagramConfiguration(configuration!, arena),
        destinationPath.toNativeUtf8(allocator: arena).cast(),
        sourcePath.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    final client = TransportClient(
      _callbacks,
      TransportOutboundChannel(
        _workerPointer,
        clientPointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
      clientPointer,
    );
    _clients[clientPointer.ref.fd] = client;
    return TransportCommunicator(client);
  }

  TransportClient? get(int fd) => _clients[fd];

  void close() {
    _clients.values.forEach((client) => client.close());
    _clients.clear();
  }

  void removeClient(int fd) => _clients.remove(fd);

  Pointer<transport_client_configuration_t> _tcpConfiguration(TransportTcpClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    nativeClientConfiguration.ref.receive_buffer_size = clientConfiguration.receiveBufferSize;
    nativeClientConfiguration.ref.send_buffer_size = clientConfiguration.sendBufferSize;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _udpConfiguration(TransportUdpClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    nativeClientConfiguration.ref.receive_buffer_size = clientConfiguration.receiveBufferSize;
    nativeClientConfiguration.ref.send_buffer_size = clientConfiguration.sendBufferSize;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _unixStreamConfiguration(TransportUnixStreamClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    nativeClientConfiguration.ref.receive_buffer_size = clientConfiguration.receiveBufferSize;
    nativeClientConfiguration.ref.send_buffer_size = clientConfiguration.sendBufferSize;
    return nativeClientConfiguration;
  }

  Pointer<transport_client_configuration_t> _unixDatagramConfiguration(TransportUnixDatagramClientConfiguration clientConfiguration, Allocator allocator) {
    final nativeClientConfiguration = allocator<transport_client_configuration_t>();
    nativeClientConfiguration.ref.receive_buffer_size = clientConfiguration.receiveBufferSize;
    nativeClientConfiguration.ref.send_buffer_size = clientConfiguration.sendBufferSize;
    return nativeClientConfiguration;
  }
}
