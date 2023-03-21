import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/logger.dart';

import 'bindings.dart';
import 'channels.dart';
import 'connector.dart';
import 'constants.dart';
import 'exception.dart';
import 'file.dart';
import 'lookup.dart';
import 'payload.dart';

String _event(int userdata) {
  if (userdata & transportEventClose != 0) return "transportEventClose";
  if (userdata & transportEventRead != 0) return "transportEventRead";
  if (userdata & transportEventWrite != 0) return "transportEventWrite";
  if (userdata & transportEventAccept != 0) return "transportEventAccept";
  if (userdata & transportEventConnect != 0) return "transportEventConnect";
  if (userdata & transportEventReadCallback != 0) return "transportEventReadCallback";
  if (userdata & transportEventWriteCallback != 0) return "transportEventWriteCallback";
  return "unkown";
}

class TransportWorkerCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;

  @pragma(preferInlinePragma)
  void putRead(int bufferId, Completer<TransportPayload> completer) => _readCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void putWrite(int bufferId, Completer<void> completer) => _writeCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyRead(int bufferId, TransportPayload payload) => _readCallbacks.remove(bufferId)!.complete(payload);

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

  final _fromTransport = ReceivePort();

  final _inboundChannels = <int, TransportInboundChannel>{};
  final _outboundChannels = <int, TransportOutboundChannel>{};
  final _servingComplter = Completer();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transportPointer;
  late final Pointer<transport_worker_t> _workerPointer;

  late final RawReceivePort _listener;
  late final RawReceivePort _activator;
  late final Pointer<transport_acceptor_t> _acceptorPointer;
  late final TransportConnector _connector;
  late final TransportWorkerCallbacks _callbacks;
  late final StreamController<TransportPayload> _serverController;
  late final Stream<TransportPayload> _serverStream;
  late final void Function(TransportInboundChannel channel)? _onAccept;
  late final SendPort? receiver;
  late final int _listenersCount;

  final _logger = TransportLogger(TransportDefaults.transport().logLevel);

  bool _hasServer = false;
  var _serving = false;
  bool get serving => _serving;

  TransportWorker(SendPort toTransport) {
    var listenerCounter = 0;
    _listener = RawReceivePort((List<dynamic> event) {
      _bindings.transport_cqe_advance(_workerPointer.ref.ring, 1);
      if (event[0] < 0) {
        _handleError(event[0], event[1]);
        return;
      }
      _handle(event[0], event[1]);
    });
    _activator = RawReceivePort((listener) {
      _bindings.transport_listener_pool_add(_workerPointer.ref.listener, Pointer.fromAddress(listener).cast());
      if (++listenerCounter == _listenersCount) _initializer.complete();
    });
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _workerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    _listenersCount = configuration[3] as int;
    receiver = configuration[4] as SendPort?;
    if (configuration.length == 6) {
      _acceptorPointer = Pointer.fromAddress(configuration[5] as int).cast<transport_acceptor_t>();
      _hasServer = true;
    }
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _fromTransport.close();
    _callbacks = TransportWorkerCallbacks();
    _serverController = StreamController();
    _serverStream = _serverController.stream;
    _connector = TransportConnector(_callbacks, _transportPointer, _workerPointer, _bindings);
    await _initializer.future;
  }

  Future<void> awaitServer() => _servingComplter.future;

  Stream<TransportPayload> serve([void Function(TransportInboundChannel channel)? onAccept]) async* {
    if (!_hasServer) throw TransportException("[server]: is not available");
    if (_serving) yield* _serverStream;
    this._onAccept = onAccept;
    _bindings.transport_worker_accept(
      _workerPointer,
      _acceptorPointer,
    );
    _serving = true;
    _logger.info("[server] accepting");
    _servingComplter.complete();
    yield* _serverStream;
  }

  Future<TransportFile> open(String path) async {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportOutboundChannel(_workerPointer, fd, _bindings));
  }

  Future<TransportClientPool> connect(String host, int port, {int? pool}) => _connector.connect(host, port, pool: pool);

  void _handleError(int result, int userData) {
    //_logger.info("[handle error] result = $result, event = ${_event(userData)}");

    if (userData & transportEventRead != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_worker_read(_workerPointer, fd, bufferId, _workerPointer.ref.used_buffers_offsets[bufferId], transportEventRead);
        return;
      }
      if (result == -EPIPE) {
        final channel = _inboundChannels.remove(fd)!;
        channel.free(bufferId);
        channel.close();
        return;
      }
      _logger.error("[inbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd");
      final channel = _inboundChannels.remove(fd)!;
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventWrite != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_worker_write(_workerPointer, fd, bufferId, _workerPointer.ref.used_buffers_offsets[bufferId], transportEventWrite);
        return;
      }
      if (result == -EPIPE) {
        final channel = _inboundChannels.remove(fd)!;
        channel.free(bufferId);
        channel.close();
        return;
      }
      _logger.error("[inbound write] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd");
      final channel = _inboundChannels.remove(fd)!;
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventAccept != 0) {
      _logger.error("[inbound accept] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, fd = ${userData & ~transportEventAll}");
      _bindings.transport_worker_accept(_workerPointer, _acceptorPointer);
      return;
    }

    if (userData & transportEventConnect != 0) {
      final message = "[connect] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, fd = ${userData & ~transportEventAll}";
      _logger.error(message);
      _bindings.transport_close_descritor(userData & ~transportEventAll);
      _callbacks.notifyConnectError(userData & ~transportEventAll, TransportException(message));
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_worker_read(_workerPointer, fd, bufferId, _workerPointer.ref.used_buffers_offsets[bufferId], transportEventReadCallback);
        return;
      }
      final message = "[outbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd";
      _logger.error(message);
      final channel = _outboundChannels[fd]!;
      _callbacks.notifyReadError(bufferId, TransportException(message));
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_worker_write(_workerPointer, fd, bufferId, _workerPointer.ref.used_buffers_offsets[bufferId], transportEventWriteCallback);
        return;
      }
      final message = "[outbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd";
      final channel = _outboundChannels[fd]!;
      _callbacks.notifyWriteError(bufferId, TransportException(message));
      channel.free(bufferId);
      channel.close();
      return;
    }
  }

  Future<void> _handle(int result, int userData) async {
    //_logger.info("[handle] result = $result, event = ${_event(userData)}, eventData = ${userData & ~transportEventAll}");

    if (userData & transportEventRead != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      if (!_serverController.hasListener) {
        _logger.warn("[server] no listeners for fd = $fd");
        _inboundChannels[fd]!.free(bufferId);
        return;
      }
      final buffer = _workerPointer.ref.buffers[bufferId];
      _serverController.add(TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), (answer, offset) {
        if (answer != null) {
          _inboundChannels[fd]!.reuse(bufferId);
          buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
          buffer.iov_len = answer.length;
          _bindings.transport_worker_write(_workerPointer, fd, bufferId, offset, transportEventWrite);
          return;
        }
        _inboundChannels[fd]!.free(bufferId);
      }));
      return;
    }

    if (userData & transportEventWrite != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      _inboundChannels[fd]!.reuse(bufferId);
      _bindings.transport_worker_read(_workerPointer, fd, bufferId, 0, transportEventRead);
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      final buffer = _workerPointer.ref.buffers[bufferId];
      _callbacks.notifyRead(
        bufferId,
        TransportPayload(
          buffer.iov_base.cast<Uint8>().asTypedList(result),
          (answer, offset) => _outboundChannels[fd]!.free(bufferId),
        ),
      );
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = _workerPointer.ref.used_buffers[bufferId];
      _outboundChannels[fd]!.free(bufferId);
      _callbacks.notifyWrite(bufferId);
      return;
    }

    if (userData & transportEventConnect != 0) {
      final fd = userData & ~transportEventAll;
      //_logger.info("[client]: connected, fd = $fd");
      _outboundChannels[fd] = TransportOutboundChannel(_workerPointer, fd, _bindings);
      _callbacks.notifyConnect(
        fd,
        TransportClient(
          _callbacks,
          _outboundChannels[fd]!,
        ),
      );
      return;
    }

    if (userData & transportEventAccept != 0) {
      _bindings.transport_worker_accept(_workerPointer, _acceptorPointer);
      //_logger.info("[server] accepted fd = $result");
      _inboundChannels[result] = TransportInboundChannel(_workerPointer, result, _bindings);
      _onAccept?.call(_inboundChannels[result]!);
      return;
    }
  }
}
