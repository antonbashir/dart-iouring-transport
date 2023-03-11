import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:iouring_transport/transport/provider.dart';

import 'bindings.dart';
import 'constants.dart';
import 'lookup.dart';

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
    _bindings.transport_channel_read(_pointer, fd, bufferId);
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
    _bindings.transport_channel_write(_pointer, fd, bufferId);
  }
}

class TransportServer {
  final fromTransport = ReceivePort();
  final toLoop = ReceivePort();

  late final TransportProvider provider;

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;
  late final TransportLogger _logger;

  TransportServer(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> serve({
    required FutureOr<void> Function(TransportServerChannel channel, int descriptor) onAccept,
    FutureOr<Uint8List> Function(Uint8List input, TransportProvider provider)? onInput,
  }) async {
    final configuration = await fromTransport.take(4).toList();
    _logger = TransportLogger(configuration[0] as TransportLogLevel);
    final libraryPath = configuration[1] as String?;
    _transport = Pointer.fromAddress(configuration[2] as int);
    int ringSize = configuration[3] as int;
    fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    await _startEventLoop(libraryPath: libraryPath);
    await _startServer(ringSize, onAccept: onAccept, onInput: onInput);
  }

  Future<void> _startEventLoop({String? libraryPath}) async {
    final fromLoop = ReceivePort();
    final loopPointer = _bindings.transport_event_loop_initialize(_transport.ref.loop_configuration, _transport.ref.channel_configuration);
    provider = TransportProvider(loopPointer, _bindings);
    Isolate.spawn<SendPort>((port) => TransportEventLoop(port)..start(), fromLoop.sendPort);
    final toLoop = await fromLoop.first as SendPort;
    toLoop.send(libraryPath);
    toLoop.send(loopPointer.address);
    fromLoop.close();
  }

  Future<void> _startServer(
    int ringSize, {
    required FutureOr<void> Function(TransportServerChannel channel, int descriptor) onAccept,
    FutureOr<Uint8List> Function(Uint8List input, TransportProvider provider)? onInput,
  }) async {
    final channelPointer = _bindings.transport_add_channel(_transport);
    final ring = channelPointer.ref.ring;
    final channel = TransportServerChannel(channelPointer, _bindings);
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(ringSize);
    while (true) {
      int cqeCount = _bindings.transport_consume(ringSize, cqes, ring);
      if (cqeCount == -1) continue;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final result = cqe.ref.res;
        final userData = cqe.ref.user_data;
        if (result < 0) {
          if (userData & transportEventRead != 0 || userData & transportEventWrite != 0) {
            _bindings.transport_close_descritor(userData & ~transportEventAll);
          }
          continue;
        }
        if (userData & transportEventRead != 0) {
          int fd = userData & ~transportEventAll;
          if (onInput == null) {
            _bindings.transport_channel_complete_read_by_fd(channelPointer, fd);
            return;
          }
          final bufferId = _bindings.transport_channel_handle_read(channelPointer, fd, result);
          final buffer = channelPointer.ref.buffers[bufferId];
          final answer = onInput(buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len), provider);
          if (answer is Future<Uint8List>) {
            await answer.then((resultBytes) {
              _bindings.transport_channel_complete_read_by_buffer_id(channelPointer, bufferId);
              buffer.iov_base.cast<Uint8>().asTypedList(resultBytes.length).setAll(0, resultBytes);
              buffer.iov_len = resultBytes.length;
              _bindings.transport_channel_write(channelPointer, fd, bufferId);
            });
            continue;
          }
          _bindings.transport_channel_complete_read_by_buffer_id(channelPointer, bufferId);
          buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
          buffer.iov_len = answer.length;
          _bindings.transport_channel_write(channelPointer, fd, bufferId);
          continue;
        }
        if (userData & transportEventWrite != 0) {
          _bindings.transport_channel_complete_write_by_fd(channelPointer, userData & ~transportEventAll);
          continue;
        }
        if (userData & transportEventAccept != 0) {
          await onAccept(channel, result);
          continue;
        }
        if (userData & transportEventClose != 0) {
          _bindings.transport_channel_close(channelPointer);
          Isolate.exit();
        }
      }
      _bindings.transport_cqe_advance(ring, cqeCount);
    }
  }
}
