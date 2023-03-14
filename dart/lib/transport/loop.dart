import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/provider.dart';

import 'bindings.dart';
import 'channels.dart';
import 'constants.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportEventLoopCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};

  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;
  void putRead(int bufferId, Completer<TransportPayload> completer) => _readCallbacks[bufferId] = completer;
  void putWrite(int bufferId, Completer<void> completer) => _writeCallbacks[bufferId] = completer;

  Completer<TransportClient>? getConnect(int fd) => _connectCallbacks[fd];
  Completer<TransportPayload>? getRead(int bufferId) => _readCallbacks[bufferId];
  Completer<void>? getWrite(int bufferId) => _writeCallbacks[bufferId];

  Completer<TransportClient>? removeConnect(int fd) => _connectCallbacks.remove(fd);
  Completer<TransportPayload>? removeRead(int bufferId) => _readCallbacks.remove(bufferId);
  Completer<void>? removeWrite(int bufferId) => _writeCallbacks.remove(bufferId);
}

class TransportEventLoop {
  bool _active = false;

  final _callbacks = TransportEventLoopCallbacks();

  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;
  late final TransportLogger _logger;
  late final Pointer<transport_channel> _channelPointer;
  late final TransportServerChannel _serverChannel;
  late final TransportResourceChannel _resourceChannel;
  late final int _ringSize;

  TransportEventLoop(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> run({
    FutureOr<void> Function(TransportProvider provider)? onRun,
    FutureOr<void> Function(TransportServerChannel channel, int descriptor)? onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    if (_active) return;

    final configuration = await fromTransport.take(5).toList();
    _logger = TransportLogger(configuration[0] as TransportLogLevel);
    final libraryPath = configuration[1] as String?;
    _transport = Pointer.fromAddress(configuration[2] as int);
    _ringSize = configuration[3] as int;
    final activationPort = configuration[4] as SendPort;
    fromTransport.close();

    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _channelPointer = _bindings.transport_add_channel(_transport);
    _serverChannel = TransportServerChannel(_channelPointer, _bindings);
    _resourceChannel = TransportResourceChannel(_channelPointer, _bindings);
    final connector = TransportConnector(_callbacks, _channelPointer, _transport, _bindings);
    final ring = _channelPointer.ref.ring;
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_ringSize);

    _active = true;

    Timer.periodic(Duration.zero, (timer) {
      int cqeCount = _bindings.transport_peek(_ringSize, cqes, ring);
      if (cqeCount == -1) {
        return;
      }
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final result = cqe.ref.res;
        final userData = cqe.ref.user_data;

        if (result < 0) {
          if (userData & transportEventRead != 0 || userData & transportEventWrite != 0) {
            final bufferId = userData & ~transportEventAll;
            final fd = _channelPointer.ref.used_buffers[bufferId];
            _bindings.transport_close_descritor(fd);
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
          }

          if (userData & transportEventConnect != 0) {
            _bindings.transport_close_descritor(userData & ~transportEventAll);
            _callbacks.getConnect(userData & ~transportEventAll)?.completeError(Exception("Connect exception with code $result"));
            _callbacks.removeConnect(userData & ~transportEventAll);
          }

          if (userData & transportEventReadCallback != 0 || userData & transportEventWriteCallback != 0) {
            final bufferId = userData & ~transportEventAll;
            final fd = _channelPointer.ref.used_buffers[bufferId];
            if (userData & transportEventReadCallback != 0) {
              _bindings.transport_close_descritor(fd);
              _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
              _callbacks.getRead(bufferId)?.completeError(Exception("Read exception with code $result"));
              _callbacks.removeRead(bufferId);
            }
            if (userData & transportEventWriteCallback != 0) {
              if (result == -11) {
                _bindings.transport_channel_write(_channelPointer, fd, bufferId, 0, transportEventWriteCallback);
                continue;
              }
              _bindings.transport_close_descritor(fd);
              _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
              _callbacks.getWrite(bufferId)?.completeError(Exception("Write exception with code $result"));
              _callbacks.removeWrite(bufferId);
            }
          }
          continue;
        }

        if (userData & transportEventRead != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = _channelPointer.ref.used_buffers[bufferId];
          if (onInput == null) {
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            continue;
          }
          final buffer = _channelPointer.ref.buffers[bufferId];
          unawaited(Future.value(onInput(buffer.iov_base.cast<Uint8>().asTypedList(result))).then((answer) {
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
            buffer.iov_len = answer.length;
            _bindings.transport_channel_write(_channelPointer, fd, bufferId, 0, transportEventWrite);
          }));
          continue;
        }

        if (userData & transportEventWrite != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = _channelPointer.ref.used_buffers[bufferId];
          _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
          _bindings.transport_channel_read(_channelPointer, fd, bufferId, 0, transportEventRead);
          continue;
        }

        if (userData & transportEventReadCallback != 0) {
          final bufferId = userData & ~transportEventAll;
          final buffer = _channelPointer.ref.buffers[bufferId];
          final callback = _callbacks.getRead(bufferId);
          if (callback == null) {
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            continue;
          }
          callback.complete(TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), () => _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable));
          continue;
        }

        if (userData & transportEventWriteCallback != 0) {
          final bufferId = userData & ~transportEventAll;
          final callback = _callbacks.getWrite(bufferId);
          _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
          callback?.complete();
          continue;
        }

        if (userData & transportEventConnect != 0) {
          final fd = userData & ~transportEventAll;
          _callbacks.getConnect(fd)?.complete(TransportClient(_callbacks, _resourceChannel, _bindings, fd));
          continue;
        }

        if (userData & transportEventAccept != 0) {
          unawaited(Future.value(onAccept?.call(_serverChannel, result)));
          continue;
        }

        if (userData & transportEventClose != 0) {
          _bindings.transport_channel_close(_channelPointer);
          Isolate.exit();
        }
      }
      _bindings.transport_cqe_advance(ring, cqeCount);
    });

    await onRun?.call(TransportProvider(connector, (path) => TransportFile(_callbacks, _resourceChannel, _bindings, path)));
    activationPort.send(null);
  }
}
