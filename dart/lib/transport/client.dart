import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'payload.dart';
import 'worker.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
  final Pointer<transport_client_t> _clientPointer;
  final TransportOutboundChannel _channel;

  TransportClient(this._callbacks, this._channel, this._clientPointer);

  Future<TransportOutboundPayload> read() async {
    final bufferId = await _channel.allocate();
    final completer = Completer<TransportOutboundPayload>();
    _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, offset: 0);
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = await _channel.allocate();
    final completer = Completer<void>();
    _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId);
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessage() async {
    final bufferId = await _channel.allocate();
    final completer = Completer<TransportOutboundPayload>();
    _callbacks.putRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _clientPointer);
    return completer.future;
  }

  Future<void> sendMessage(Uint8List bytes) async {
    final bufferId = await _channel.allocate();
    final completer = Completer<void>();
    _callbacks.putWrite(bufferId, completer);
    _channel.sendMessage(bytes, bufferId, _clientPointer);
    return completer.future;
  }

  void shutdown() => _channel.close();
}

class TransportClientPool {
  final List<TransportClient> _clients;
  var _next = 0;

  TransportClientPool(this._clients);

  TransportClient select() {
    final client = _clients[_next];
    if (++_next == _clients.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportClient client) action) => _clients.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportClient client) mapper) => _clients.map(mapper);
}

class TransportClientRegistry {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_t> _transportPointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportWorker _worker;
  final Queue<Completer<int>> _bufferFinalizers;
  final _clients = <int, Pointer<transport_client_t>>{};

  TransportClientRegistry(this._callbacks, this._transportPointer, this._workerPointer, this._bindings, this._bufferFinalizers, this._worker);

  Future<TransportClientPool> createTcp(String host, int port, {int? pool}) async {
    final clients = <Future<TransportClient>>[];
    if (pool == null) pool = _transportPointer.ref.client_configuration.ref.default_pool;
    for (var clientIndex = 0; clientIndex < pool; clientIndex++) {
      final client = using((arena) => _bindings.transport_client_initialize_tcp(
            _transportPointer.ref.client_configuration,
            host.toNativeUtf8(allocator: arena).cast(),
            port,
          ));
      _clients[client.ref.fd] = client;
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(client.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, client);
      clients.add(completer.future);
    }
    return TransportClientPool(await Future.wait(clients));
  }

  Future<TransportClientPool> createUnixStream(String path, {int? pool}) async {
    final clients = <Future<TransportClient>>[];
    if (pool == null) pool = _transportPointer.ref.client_configuration.ref.default_pool;
    for (var clientIndex = 0; clientIndex < pool; clientIndex++) {
      final client = using((arena) => _bindings.transport_client_initialize_unix_stream(
            _transportPointer.ref.client_configuration,
            path.toNativeUtf8(allocator: arena).cast(),
            path.length,
          ));
      _clients[client.ref.fd] = client;
      final completer = Completer<TransportClient>();
      _callbacks.putConnect(client.ref.fd, completer);
      _bindings.transport_worker_connect(_workerPointer, client);
      clients.add(completer.future);
    }
    return TransportClientPool(await Future.wait(clients));
  }

  TransportClient createUdp(String sourceHost, int sourcePort, String destinationHost, int destinationPort) {
    final client = using(
      (arena) => _bindings.transport_client_initialize_udp(
        _transportPointer.ref.client_configuration,
        destinationHost.toNativeUtf8(allocator: arena).cast(),
        destinationPort,
        sourceHost.toNativeUtf8(allocator: arena).cast(),
        sourcePort,
      ),
    );
    _clients[client.ref.fd] = client;
    return TransportClient(
      _callbacks,
      TransportOutboundChannel(
        _workerPointer,
        client.ref.fd,
        _bindings,
        _bufferFinalizers,
        _worker,
      ),
      client,
    );
  }

  TransportClient createUnixDatagram(String sourcePath, String destinationPath) {
    final client = using(
      (arena) => _bindings.transport_client_initialize_unix_dgram(
        _transportPointer.ref.client_configuration,
        destinationPath.toNativeUtf8(allocator: arena).cast(),
        destinationPath.length,
        sourcePath.toNativeUtf8(allocator: arena).cast(),
        sourcePath.length,
      ),
    );
    _clients[client.ref.fd] = client;
    return TransportClient(
      _callbacks,
      TransportOutboundChannel(
        _workerPointer,
        client.ref.fd,
        _bindings,
        _bufferFinalizers,
        _worker,
      ),
      client,
    );
  }

  TransportClient createConnectedClient(int fd) => TransportClient(
        _callbacks,
        TransportOutboundChannel(
          _workerPointer,
          fd,
          _bindings,
          _bufferFinalizers,
          _worker,
        ),
        _clients[fd]!,
      );

  Pointer<transport_client_t> get(int fd) => _clients[fd]!;

  void shutdown() => _clients.values.forEach((client) => _bindings.transport_client_shutdown(client));
}
