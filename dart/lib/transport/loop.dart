import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';
import 'package:iouring_transport/transport/logger.dart';

import 'bindings.dart';
import 'constants.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportServerChannel {
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  TransportServerChannel(this._pointer, this._bindings);

  Future<void> read(int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    _bindings.transport_channel_read(_pointer, fd, bufferId, 0, transportEventRead);
  }

  Future<void> write(Uint8List bytes, int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId, 0, transportEventWrite);
  }
}

class TransportResourceChannel {
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  TransportResourceChannel(this._pointer, this._bindings);

  Future<void> read(int fd, {int offset = 0}) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    _bindings.transport_channel_read(_pointer, fd, bufferId, offset, transportEventReadCallback);
  }

  Future<void> write(Uint8List bytes, int fd, {int offset = 0}) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId, offset, transportEventWriteCallback);
  }
}

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
}

class TransportEventLoop {
  bool _initialized = false;

  final _callbacks = TransportEventLoopCallbacks();

  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;
  late final TransportLogger _logger;
  late final Pointer<transport_channel> _channelPointer;
  late final TransportServerChannel _serverChannel;
  late final TransportResourceChannel _resourceChannel;
  late final int _ringSize;

  late final TransportConnector _connector;

  TransportEventLoop(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<TransportEventLoop> initialize() async {
    if (_initialized) return this;

    final configuration = await fromTransport.take(4).toList();
    _logger = TransportLogger(configuration[0] as TransportLogLevel);
    final libraryPath = configuration[1] as String?;
    _transport = Pointer.fromAddress(configuration[2] as int);
    _ringSize = configuration[3] as int;
    fromTransport.close();

    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _channelPointer = _bindings.transport_add_channel(_transport);
    _serverChannel = TransportServerChannel(_channelPointer, _bindings);
    _resourceChannel = TransportResourceChannel(_channelPointer, _bindings);
    _connector = TransportConnector(_callbacks, _channelPointer, _transport, _bindings);

    _initialized = true;
    return this;
  }

  TransportConnector get connector => _connector;

  TransportFile file(String path) => TransportFile(_callbacks, _resourceChannel, _bindings, path);

  Future<void> run({
    void Function()? onRun,
    FutureOr<void> Function(TransportServerChannel channel, int descriptor)? onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    await initialize();
    final ring = _channelPointer.ref.ring;
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_ringSize);
    Timer.periodic(Duration.zero, (timer) {
      int cqeCount = _bindings.transport_consume(_ringSize, cqes, ring);
      if (cqeCount == -1) return;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final result = cqe.ref.res;
        final userData = cqe.ref.user_data;

        if (result < 0) {
          if (userData & transportEventConnect != 0 ||
              userData & transportEventRead != 0 ||
              userData & transportEventWrite != 0 ||
              userData & transportEventReadCallback != 0 ||
              userData & transportEventWriteCallback != 0) {
            _bindings.transport_close_descritor(userData & ~transportEventAll);
          }
          continue;
        }

        if (userData & transportEventRead != 0) {
          int bufferId = userData & ~transportEventAll;
          int fd = _channelPointer.ref.used_buffers[bufferId];
          if (onInput == null) {
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            return;
          }
          final buffer = _channelPointer.ref.buffers[bufferId];
          Future.value(onInput(buffer.iov_base.cast<Uint8>().asTypedList(result))).then((answer) {
            _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
            buffer.iov_len = answer.length;
            _bindings.transport_channel_write(_channelPointer, fd, bufferId, 0, transportEventWrite);
          });
          continue;
        }

        if (userData & transportEventWrite != 0) {
          int bufferId = userData & ~transportEventAll;
          _channelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
          continue;
        }

        if (userData & transportEventReadCallback != 0) {
          int bufferId = userData & ~transportEventAll;
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
          int bufferId = userData & ~transportEventAll;
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
          onAccept?.call(_serverChannel, result);
          continue;
        }

        if (userData & transportEventClose != 0) {
          _bindings.transport_channel_close(_channelPointer);
          timer.cancel();
          Isolate.exit();
        }
      }
      _bindings.transport_cqe_advance(ring, cqeCount);
    });
    onRun?.call();
  }
}
