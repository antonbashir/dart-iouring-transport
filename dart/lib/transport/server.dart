import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'bindings.dart';
import 'channel.dart';
import 'constants.dart';
import 'lookup.dart';

class TransportServer {
  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

  TransportServer(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> serve({
    FutureOr Function(TransportChannel channel, int descriptor)? onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    final configuration = await fromTransport.take(2).toList();
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    fromTransport.close();
    final _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    final channelPointer = _bindings.transport_add_channel(_transport);
    final ring = channelPointer.ref.ring;
    final channel = TransportChannel(channelPointer, _bindings, onRead: onInput == null ? null : (payload, fd) => onInput(payload));
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_transport);
    while (true) {
      int cqeCount = _bindings.transport_consume(_transport, cqes, ring);
      if (cqeCount == -1) continue;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final result = cqe.ref.res;
        final userData = cqe.ref.user_data;
        if (result < 0) {
          if (userData & TransportPayloadRead != 0 || userData & TransportPayloadWrite != 0) {
            _bindings.transport_close_descritor(_transport, userData & ~TransportPayloadAll);
          }
          continue;
        }
        if (userData & TransportPayloadRead != 0) {
          await channel.handleRead(userData & ~TransportPayloadAll, result);
          continue;
        }
        if (userData & TransportPayloadWrite != 0) {
          await channel.handleWrite(userData & ~TransportPayloadAll, result);
          continue;
        }
        if (userData & TransportPayloadActive != 0) {
          if (onAccept != null) onAccept.call(channel, result);
          continue;
        }
        if (userData & TransportPayloadClose != 0) {
          _bindings.transport_channel_close(channelPointer);
          Isolate.exit();
        }
      }
      _bindings.transport_cqe_advance(ring, cqeCount);
    }
  }
}
