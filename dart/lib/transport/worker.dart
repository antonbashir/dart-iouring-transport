import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';
import 'package:iouring_transport/transport/model.dart';

import 'bindings.dart';
import 'channels.dart';
import 'connector.dart';
import 'constants.dart';
import 'defaults.dart';
import 'exception.dart';
import 'file.dart';
import 'logger.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportOutboundPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;

  @pragma(preferInlinePragma)
  void putRead(int bufferId, Completer<TransportOutboundPayload> completer) => _readCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void putWrite(int bufferId, Completer<void> completer) => _writeCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyRead(int bufferId, TransportOutboundPayload payload) => _readCallbacks.remove(bufferId)!.complete(payload);

  @pragma(preferInlinePragma)
  void notifyWrite(int bufferId) => _writeCallbacks.remove(bufferId)!.complete();

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connectCallbacks.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyReadError(int bufferId, Exception error) => _readCallbacks.remove(bufferId)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyWriteError(int bufferId, Exception error) => _writeCallbacks.remove(bufferId)!.completeError(error);
}

class TransportWorker {
  final _initializer = Completer();
  final _logger = TransportLogger(TransportDefaults.transport().logLevel);
  final _fromTransport = ReceivePort();
  final _bufferFinalizers = Queue<Completer<int>>();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transportPointer;
  late final Pointer<transport_worker_t> _workerPointer;
  late final Pointer<transport_acceptor_t> _acceptorPointer;
  late final Pointer<io_uring> _ring;
  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;
  late final Pointer<Pointer<io_uring_cqe>> _cqes;

  late final RawReceivePort _listener;
  late final RawReceivePort _activator;
  late final TransportConnector _connector;
  late final TransportCallbacks _callbacks;
  late final StreamController<TransportInboundPayload> _serverController;
  late final Stream<TransportInboundPayload> _serverStream;
  late final void Function(TransportInboundChannel channel) _onAccept;

  late final SendPort? transmitter;

  bool _hasServer = false;
  var _serving = false;

  bool get serving => _serving;

  TransportWorker(SendPort toTransport) {
    _listener = RawReceivePort((_) {
      final cqeCount = _bindings.transport_peek(_transportPointer.ref.worker_configuration.ref.ring_size, _cqes, _ring);
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = _cqes[cqeIndex];
        final result = cqe.ref.res;
        final data = cqe.ref.user_data;
        _bindings.transport_cqe_advance(_ring, 1);
        final event = data & 0xffff;
        if (event & transportEventAll != 0) {
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
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _workerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    transmitter = configuration[3] as SendPort?;
    if (configuration.length == 5) {
      _acceptorPointer = Pointer.fromAddress(configuration[4] as int).cast<transport_acceptor_t>();
      _hasServer = true;
    }
    _fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _callbacks = TransportCallbacks();
    _serverController = StreamController();
    _serverStream = _serverController.stream;
    _connector = TransportConnector(_callbacks, _transportPointer, _workerPointer, _bindings);
    await _initializer.future;
    _ring = _workerPointer.ref.ring;
    _cqes = _bindings.transport_allocate_cqes(_transportPointer.ref.worker_configuration.ref.ring_size);
    _usedBuffers = _workerPointer.ref.used_buffers;
    _buffers = _workerPointer.ref.buffers;
    _activator.close();
  }

  Future<void> serve(void Function(TransportInboundChannel channel) onAccept, void Function(Stream<TransportInboundPayload> stream) handler) async {
    if (!_hasServer) throw TransportException("[server]: is not available");
    if (_serving) {
      handler(_serverStream);
      return;
    }
    this._onAccept = onAccept;
    _bindings.transport_worker_accept(
      _workerPointer,
      _acceptorPointer,
    );
    _serving = true;
    handler(_serverStream);
  }

  Future<TransportFile> open(String path) async {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportOutboundChannel(_workerPointer, fd, _bindings, _bufferFinalizers));
  }

  Future<TransportClientPool> connect(TransportUri uri, {int? pool}) => _connector.connect(uri, pool: pool);

  @pragma(preferInlinePragma)
  void _handleError(int result, int userData, int fd, int event) {
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
        _bindings.transport_worker_accept(_workerPointer, _acceptorPointer);
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
    switch (event) {
      case transportEventRead:
        final bufferId = ((userData >> 16) & 0xffff);
        if (!_serverController.hasListener) {
          _logger.warn("[server]: stream hasn't listeners for fd = $fd");
          _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
          if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
          return;
        }
        final buffer = _buffers[bufferId];
        final bufferBytes = buffer.iov_base.cast<Uint8>();
        _serverController.add(TransportInboundPayload(
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
      case transportEventWrite:
        final bufferId = ((userData >> 16) & 0xffff);
        _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
        _bindings.transport_worker_read(_workerPointer, fd, bufferId, 0, transportEventRead);
        return;
      case transportEventReadCallback:
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
        final bufferId = ((userData >> 16) & 0xffff);
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _callbacks.notifyWrite(bufferId);
        return;
      case transportEventConnect:
        _callbacks.notifyConnect(fd, TransportClient(_callbacks, TransportOutboundChannel(_workerPointer, fd, _bindings, _bufferFinalizers)));
        return;
      case transportEventAccept:
        _bindings.transport_worker_accept(_workerPointer, _acceptorPointer);
        _onAccept(TransportInboundChannel(_workerPointer, result, _bindings, _bufferFinalizers));
        return;
    }
  }
}
