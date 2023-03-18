import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/logger.dart';

import 'bindings.dart';
import 'channels.dart';
import 'connector.dart';
import 'constants.dart';
import 'exception.dart';
import 'file.dart';
import 'payload.dart';
import 'transport.dart';

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

class TransportEventLoopCallbacks {
  final int _maxCallbacks;
  final TransportLogger _logger;

  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};
  final _callbackFinalizers = Queue<Completer<int>>();

  final _usedCallbacks = <int, int>{};
  var _availableCallbackId = 0;

  TransportEventLoopCallbacks(this._maxCallbacks, this._logger);

  @pragma(preferInlinePragma)
  Future<int> _allocateCallback(int bufferId) async {
    while (_usedCallbacks.containsKey(_availableCallbackId)) {
      if (++_availableCallbackId >= _maxCallbacks) {
        _availableCallbackId = 0;
        if (_usedCallbacks.containsKey(_availableCallbackId)) {
          _logger.info("callback overflow, await");
          final completer = Completer<int>();
          _callbackFinalizers.add(completer);
          _availableCallbackId = await completer.future;
          break;
        }
      }
    }

    _usedCallbacks[_availableCallbackId] = bufferId;
    return _availableCallbackId;
  }

  @pragma(preferInlinePragma)
  int _freeCallback(int id) {
    int bufferId = _usedCallbacks.remove(id)!;
    if (_callbackFinalizers.isNotEmpty) _callbackFinalizers.removeFirst().complete(id);
    return bufferId;
  }

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;

  @pragma(preferInlinePragma)
  Future<int> putRead(int bufferId, Completer<TransportPayload> completer) async {
    final callbackId = await _allocateCallback(bufferId);
    _readCallbacks[callbackId] = completer;
    return callbackId;
  }

  @pragma(preferInlinePragma)
  Future<int> putWrite(int bufferId, Completer<void> completer) async {
    final callbackId = await _allocateCallback(bufferId);
    _writeCallbacks[callbackId] = completer;
    return callbackId;
  }

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  int notifyRead(int id, TransportPayload payload) {
    _readCallbacks.remove(id)!.complete(payload);
    return _freeCallback(id);
  }

  @pragma(preferInlinePragma)
  int notifyWrite(int id) {
    _writeCallbacks.remove(id)!.complete();
    return _freeCallback(id);
  }

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connectCallbacks.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  int notifyReadError(int id, Exception error) {
    _readCallbacks.remove(id)!.completeError(error);
    return _freeCallback(id);
  }

  @pragma(preferInlinePragma)
  int notifyWriteError(int id, Exception error) {
    _writeCallbacks.remove(id)!.completeError(error);
    return _freeCallback(id);
  }
}

class TransportEventLoop {
  final _inboundChannels = <int, TransportInboundChannel>{};
  final _outboundChannels = <int, TransportOutboundChannel>{};
  final _servingComplter = Completer();

  final TransportBindings _bindings;
  final Pointer<transport_t> _transportPointer;
  final SendPort _onShutdown;
  final Transport _transport;

  late final RawReceivePort _listener;
  late final Pointer<transport_acceptor_t> _acceptorPointer;
  late final TransportConnector _connector;
  late final TransportEventLoopCallbacks _callbacks;
  late final StreamController<TransportPayload> _serverController;
  late final Stream<TransportPayload> _serverStream;
  late final void Function(TransportInboundChannel channel)? _onAccept;

  var _serving = false;
  bool get serving => _serving;

  TransportEventLoop(
    this._bindings,
    this._transportPointer,
    this._transport,
    this._onShutdown,
    void Function(RawReceivePort listener) completer,
  ) {
    _callbacks = TransportEventLoopCallbacks(
      (_transport.channelConfiguration.buffersCount * _transport.transportConfiguration.isolates) - 1,
      _transport.logger,
    );
    _serverController = StreamController();
    _serverStream = _serverController.stream;
    _connector = TransportConnector(_callbacks, _transportPointer, _bindings, _transport);
    _listener = RawReceivePort((List<dynamic> input) {
      for (var element in input) {
        if (element[0] < 0) {
          _handleError(element[0], element[1], Pointer.fromAddress(element[2]));
          continue;
        }
        _handle(element[0], element[1], Pointer.fromAddress(element[2]));
      }
    });
    completer(_listener);
  }

  Future<void> awaitServer() => _servingComplter.future;

  Stream<TransportPayload> serve(
    String host,
    int port, {
    void Function(TransportInboundChannel channel)? onAccept,
  }) async* {
    if (_serving) yield* _serverStream;
    this._onAccept = onAccept;
    _acceptorPointer = using((arena) => _bindings.transport_acceptor_initialize(
          _transportPointer.ref.acceptor_configuration,
          host.toNativeUtf8(allocator: arena).cast(),
          port,
        ));
    _bindings.transport_channel_accept(
      _bindings.transport_channel_pool_next(_transportPointer.ref.channels),
      _acceptorPointer,
    );
    _serving = true;
    _transport.logger.info("[server] accepting");
    _servingComplter.complete();
    yield* _serverStream;
  }

  Future<TransportFile> open(String path) async {
    final channelPointer = _bindings.transport_channel_pool_next(_transportPointer.ref.channels);
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportOutboundChannel(channelPointer, fd, _bindings));
  }

  Future<TransportClientPool> connect(String host, int port, {int? pool}) => _connector.connect(host, port, pool: pool);

  void _handleError(int result, int userData, Pointer<transport_channel_t> pointer) {
    //_transport.logger.info("[handle error] result = $result, event = ${_event(userData)}");

    if (userData & transportEventRead != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_channel_read(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], bufferId | transportEventRead);
        return;
      }
      if (result == -EPIPE) {
        final channel = _inboundChannels.remove(fd)!;
        channel.free(bufferId);
        channel.close();
        return;
      }
      _transport.logger.error("[inbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd");
      final channel = _inboundChannels.remove(fd)!;
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventWrite != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_channel_write(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], bufferId | transportEventWrite);
        return;
      }
      if (result == -EPIPE) {
        final channel = _inboundChannels.remove(fd)!;
        channel.free(bufferId);
        channel.close();
        return;
      }
      _transport.logger.error("[inbound write] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd");
      final channel = _inboundChannels.remove(fd)!;
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventAccept != 0) {
      _transport.logger.error("[inbound accept] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, fd = ${userData & ~transportEventAll}");
      _bindings.transport_channel_accept(pointer, _acceptorPointer);
      return;
    }

    if (userData & transportEventConnect != 0) {
      final message = "[connect] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, fd = ${userData & ~transportEventAll}";
      _transport.logger.error(message);
      _bindings.transport_close_descritor(userData & ~transportEventAll);
      _callbacks.notifyConnectError(userData & ~transportEventAll, TransportException(message));
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final callbackId = userData & ~transportEventAll;
      final bufferId = _callbacks._usedCallbacks[callbackId]!;
      final fd = pointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_channel_read(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], callbackId | transportEventReadCallback);
        return;
      }
      final message = "[outbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd";
      _transport.logger.error(message);
      final channel = _outboundChannels[fd]!;
      _callbacks.notifyReadError(callbackId, TransportException(message));
      channel.free(bufferId);
      channel.close();
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final callbackId = userData & ~transportEventAll;
      final bufferId = _callbacks._usedCallbacks[callbackId]!;
      final fd = pointer.ref.used_buffers[bufferId];
      if (result == -EAGAIN) {
        _bindings.transport_channel_write(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], callbackId | transportEventWriteCallback);
        return;
      }
      final message = "[outbound read] code = $result, message = ${_bindings.strerror(-result).cast<Utf8>().toDartString()}, bufferId = $bufferId, fd = $fd";
      final channel = _outboundChannels[fd]!;
      _callbacks.notifyWriteError(callbackId, TransportException(message));
      channel.free(bufferId);
      channel.close();
      return;
    }
  }

  Future<void> _handle(int result, int userData, Pointer<transport_channel_t> pointer) async {
    //_transport.logger.info("[handle] result = $result, event = ${_event(userData)}, eventData = ${userData & ~transportEventAll}");

    if (userData & transportEventRead != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      if (!_serverController.hasListener) {
        _transport.logger.warn("[server] no listeners for fd = $fd");
        _inboundChannels[fd]!.free(bufferId);
        return;
      }
      final buffer = pointer.ref.buffers[bufferId];
      _serverController.add(TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), (answer, offset) {
        if (answer != null) {
          _inboundChannels[fd]!.reset(bufferId);
          buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
          buffer.iov_len = answer.length;
          _bindings.transport_channel_write(pointer, fd, bufferId, offset, bufferId | transportEventWrite);
          return;
        }
        _inboundChannels[fd]!.free(bufferId);
      }));
      return;
    }

    if (userData & transportEventWrite != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      _inboundChannels[fd]!.reset(bufferId);
      _bindings.transport_channel_read(pointer, fd, bufferId, 0, bufferId | transportEventRead);
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final callbackId = userData & ~transportEventAll;
      final bufferId = _callbacks._usedCallbacks[callbackId]!;
      final fd = pointer.ref.used_buffers[bufferId];
      final buffer = pointer.ref.buffers[bufferId];
      _callbacks.notifyRead(
        callbackId,
        TransportPayload(
          buffer.iov_base.cast<Uint8>().asTypedList(result),
          (answer, offset) => _outboundChannels[fd]!.free(bufferId),
        ),
      );
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final callbackId = userData & ~transportEventAll;
      final bufferId = _callbacks.notifyWrite(callbackId);
      final fd = pointer.ref.used_buffers[bufferId];
      _outboundChannels[fd]!.free(bufferId);
      return;
    }

    if (userData & transportEventConnect != 0) {
      final fd = userData & ~transportEventAll;
      _transport.logger.info("[client]: connected, fd = $fd");
      _outboundChannels[fd] = TransportOutboundChannel(pointer, fd, _bindings);
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
      _bindings.transport_channel_accept(_bindings.transport_channel_pool_next(_transportPointer.ref.channels), _acceptorPointer);
      _transport.logger.info("[server] accepted fd = $result");
      _inboundChannels[result] = TransportInboundChannel(pointer, result, _bindings);
      _onAccept?.call(_inboundChannels[result]!);
      return;
    }
  }
}
