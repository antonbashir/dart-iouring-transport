import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/logger.dart';

import 'bindings.dart';
import 'channel.dart';
import 'constants.dart';
import 'lookup.dart';

class TransportServer {
  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;
  late final TransportLogger _logger;

  TransportServer(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> serve({
    required FutureOr<void> Function(TransportChannel channel, int descriptor) onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    final configuration = await fromTransport.take(4).toList();
    _logger = TransportLogger(configuration[0] as TransportLogLevel);
    final libraryPath = configuration[1] as String?;
    _transport = Pointer.fromAddress(configuration[2] as int);
    int ringSize = configuration[3] as int;
    fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    final channelPointer = _bindings.transport_add_channel(_transport);
    final ring = channelPointer.ref.ring;
    final channel = TransportChannel(
      channelPointer,
      _bindings,
      _logger,
      onRead: onInput == null ? null : (payload, fd) => onInput(payload),
    );
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
            _bindings.transport_close_descritor(_transport, userData & ~transportEventAll);
          }
          continue;
        }
        if (userData & transportEventRead != 0) {
          await channel.handleRead(userData & ~transportEventAll, result);
          continue;
        }
        if (userData & transportEventWrite != 0) {
          await channel.handleWrite(userData & ~transportEventAll, result);
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
