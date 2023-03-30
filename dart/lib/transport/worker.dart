import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'channels.dart';
import 'connector.dart';
import 'constants.dart';
import 'exception.dart';
import 'file.dart';
import 'logger.dart';
import 'lookup.dart';
import 'payload.dart';
import 'server.dart';

class TransportCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportOutboundPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};
  final _customCallbacks = <int, Completer<int>>{};

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;

  @pragma(preferInlinePragma)
  void putRead(int bufferId, Completer<TransportOutboundPayload> completer) => _readCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void putWrite(int bufferId, Completer<void> completer) => _writeCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void putCustom(int id, Completer<int> completer) => _customCallbacks[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyRead(int bufferId, TransportOutboundPayload payload) => _readCallbacks.remove(bufferId)!.complete(payload);

  @pragma(preferInlinePragma)
  void notifyWrite(int bufferId) => _writeCallbacks.remove(bufferId)!.complete();

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _customCallbacks[id]!.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connectCallbacks.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyReadError(int bufferId, Exception error) => _readCallbacks.remove(bufferId)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyWriteError(int bufferId, Exception error) => _writeCallbacks.remove(bufferId)!.completeError(error);
}

class TransportWorker {
  final _initializer = Completer();
  final _fromTransport = ReceivePort();
  final _bufferFinalizers = Queue<Completer<int>>();
  final _serversByClients = <int, TransportServerInstance>{};

  late final TransportLogger logger;
  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transportPointer;
  late final Pointer<transport_worker_t> _workerPointer;
  late final Pointer<io_uring> _ring;
  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;
  late final Pointer<Pointer<io_uring_cqe>> _cqes;
  late final RawReceivePort _listener;
  late final RawReceivePort _activator;
  late final RawReceivePort _closer;
  late final TransportConnector _connector;
  late final TransportServer _server;
  late final TransportCallbacks _callbacks;
  late int _ringSize;

  late final SendPort? transmitter;

  TransportWorker(SendPort toTransport) {
    _listener = RawReceivePort((_) {
      final cqeCount = _bindings.transport_worker_peek(_ringSize, _cqes, _ring);
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = _cqes[cqeIndex];
        final data = cqe.ref.user_data;
        final result = cqe.ref.res;
        _bindings.transport_cqe_advance(_ring, 1);
        final event = data & 0xffff;
        if (event & transportEventAll != 0) {
          if (event == transportEventCustomCallback) {
            _callbacks.notifyCustom(result, data);
            continue;
          }
          final fd = (data >> 32) & 0xffffffff;
          if (result < 0) {
            _handleError(result, data, fd, event);
            continue;
          }
          _handle(result, data, fd, event);
        }
      }
    });
    _activator = RawReceivePort((_) => _initializer.complete());
    _closer = RawReceivePort((_) async {
      _listener.close();
      _closer.close();
      _server.shutdown();
      //final id = _workerPointer.ref.id;
      _bindings.transport_worker_destroy(_workerPointer);
      //logger.debug("[worker $id]: closed");
      Isolate.exit();
    });
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort, _closer.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _workerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    transmitter = configuration[3] as SendPort?;
    _fromTransport.close();
    logger = TransportLogger(TransportLogLevel.values[_transportPointer.ref.transport_configuration.ref.log_level]);
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _callbacks = TransportCallbacks();
    _connector = TransportConnector(
      _callbacks,
      _transportPointer,
      _workerPointer,
      _bindings,
      _bufferFinalizers,
      this,
    );
    _server = TransportServer(_transportPointer.ref.server_configuration, _bindings);
    await _initializer.future;
    _ring = _workerPointer.ref.ring;
    _cqes = _bindings.transport_allocate_cqes(_transportPointer.ref.worker_configuration.ref.ring_size);
    _usedBuffers = _workerPointer.ref.used_buffers;
    _buffers = _workerPointer.ref.buffers;
    _ringSize = _transportPointer.ref.worker_configuration.ref.ring_size;
    _activator.close();
  }

  void serveTcp(
    String host,
    int port,
    void Function(TransportInboundChannel channel) onAccept,
    void Function(Stream<TransportInboundPayload> stream) handler,
  ) {
    final server = _server.createTcp(host, port);
    server.accept(_workerPointer, onAccept);
    handler(server.stream);
  }

  void serveUdp(
    String host,
    int port,
    void Function(Stream<TransportInboundPayload> stream) handler,
  ) =>
      handler(_server.createUdp(host, port).stream);

  void serveUnixStream(
    String path,
    void Function(Stream<TransportInboundPayload> stream) handler,
  ) =>
      handler(_server.createUnixStream(path).stream);

  void serveUnixDgram(
    String path,
    void Function(Stream<TransportInboundPayload> stream) handler,
  ) =>
      handler(_server.createUnixDgram(path).stream);

  Future<TransportFile> file(String path) async {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportOutboundChannel(_workerPointer, fd, _bindings, _bufferFinalizers, this));
  }

  Future<TransportClientPool> connectTcp(String host, int port, {int? pool}) => _connector.connect(host, port, pool: pool);

  TransportClientPool createUdpClients(String host, int port, {int? pool}) => _connector.createUdpClients(host, port, pool: pool);

  TransportClientPool createUnixStreamClients(String path, {int? pool}) => _connector.createUnixStreamClients(path, pool: pool);

  TransportClientPool createUnixDgramClients(String path, {int? pool}) => _connector.createUnixDgramClients(path, pool: pool);

  void registerCallback(int id, Completer<int> completer) => _callbacks.putCustom(id, completer);

  @pragma(preferInlinePragma)
  void _handleError(int result, int userData, int fd, int event) {
    //logger.debug("[error]: ${TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd).message}");

    switch (event) {
      case transportEventRead:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_read(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventRead);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        return;
      case transportEventWrite:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_write(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventWrite);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        return;
      case transportEventAccept:
        _bindings.transport_worker_accept(_workerPointer, _server.get(fd).pointer);
        return;
      case transportEventConnect:
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyConnectError(
          fd,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
          ),
        );
        return;
      case transportEventReadCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_read(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventReadCallback);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyReadError(
          bufferId,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
            bufferId: bufferId,
          ),
        );
        return;
      case transportEventWriteCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_write(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventWriteCallback);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyWriteError(
          bufferId,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
            bufferId: bufferId,
          ),
        );
        return;
    }
  }

  @pragma(preferInlinePragma)
  void _handle(int result, int userData, int fd, int event) {
    //logger.debug("${event.transportEventToString()} worker = ${_workerPointer.ref.id}, result = $result, fd = $fd");

    switch (event) {
      case transportEventRead:
        final bufferId = ((userData >> 16) & 0xffff);
        final server = _serversByClients[fd]!;
        if (!server.controller.hasListener) {
          logger.debug("[server]: stream hasn't listeners for fd = $fd");
          _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
          if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
          return;
        }
        final buffer = _buffers[bufferId];
        final bufferBytes = buffer.iov_base.cast<Uint8>();
        server.controller.add(TransportInboundPayload(
          bufferBytes.asTypedList(result),
          (answer) {
            _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
            bufferBytes.asTypedList(answer.length).setAll(0, answer);
            buffer.iov_len = answer.length;
            _bindings.transport_worker_write(_workerPointer, fd, bufferId, 0, transportEventWrite);
          },
          () {
            _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
            if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
          },
        ));
        return;
      case transportEventReceiveMessage:
        final bufferId = ((userData >> 16) & 0xffff);
        final server = _serversByClients[fd]!;
        if (!server.controller.hasListener) {
          logger.debug("[server]: stream hasn't listeners for fd = $fd");
          _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
          if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
          return;
        }
        final buffer = _buffers[bufferId];
        final bufferBytes = buffer.iov_base.cast<Uint8>();
        server.controller.add(TransportInboundPayload(
          bufferBytes.asTypedList(result),
          (answer) {
            _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
            bufferBytes.asTypedList(answer.length).setAll(0, answer);
            buffer.iov_len = answer.length;
            _bindings.transport_worker_send_message(
              _workerPointer,
              fd,
              bufferId,
              server.pointer.ref.inet_server_address,
              server.pointer.ref.server_address_length,
              MSG_TRUNC,
              transportEventSendMessage,
            );
          },
          () {
            _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
            if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
          },
        ));
        return;
      case transportEventWrite:
        final bufferId = ((userData >> 16) & 0xffff);
        _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
        _bindings.transport_worker_read(_workerPointer, fd, bufferId, 0, transportEventRead);
        //logger.debug("[inbound send read]: worker = ${_workerPointer.ref.id}, fd = $fd");
        return;
      case transportEventReadCallback:
      case transportEventReceiveMessage:
        final bufferId = ((userData >> 16) & 0xffff);
        _callbacks.notifyRead(
          bufferId,
          TransportOutboundPayload(
            _buffers[bufferId].iov_base.cast<Uint8>().asTypedList(result),
            () {
              _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
              if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
            },
          ),
        );
        return;
      case transportEventWriteCallback:
      case transportEventSendMessageCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _callbacks.notifyWrite(bufferId);
        return;
      case transportEventConnect:
        _callbacks.notifyConnect(fd, _connector.createClient(fd));
        return;
      case transportEventAccept:
        final server = _server.get(fd);
        _serversByClients[result] = server;
        _bindings.transport_worker_accept(_workerPointer, server.pointer);
        server.acceptor!(TransportInboundChannel(
          _workerPointer,
          result,
          _bindings,
          _bufferFinalizers,
          this,
          server.pointer,
        ));
        return;
    }
  }
}
