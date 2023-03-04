import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'bindings.dart';
import 'channels/channel.dart';
import 'lookup.dart';
import 'payload.dart';

const TransportPayloadRead = 1 << (64 - 1 - 0);
const TransportPayloadWrite = 1 << (64 - 1 - 1);
const TransportPayloadAccept = 1 << (64 - 1 - 2);
const TransportPayloadConnect = 1 << (64 - 1 - 3);
const TransportPayloadAll = TransportPayloadRead | TransportPayloadWrite | TransportPayloadAccept | TransportPayloadConnect;

class TransportWorker {
  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

  final fromTransport = ReceivePort();

  TransportWorker(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> start({
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) async {
    final configuration = await fromTransport.take(2).toList();
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    final _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    final ring = _bindings.transport_activate(_transport);
    final channel = TransportChannel.fromPointer(
      _transport.ref.channel,
      _bindings,
      onRead: onRead,
      onWrite: onWrite,
      onStop: onStop,
    );
    while (true) {
      Pointer<io_uring_cqe> cqe = _bindings.transport_consume(_transport, ring);
      if (cqe == nullptr) continue;

      final int result = cqe.ref.res;
      final int userData = cqe.ref.user_data;
      _bindings.transport_cqe_seen(ring, cqe);

      if (result < 0) {
        continue;
      }

      if (userData & TransportPayloadAccept != 0) {
        channel.handleAccept(result);
        continue;
      }

      if (userData & TransportPayloadRead != 0) {
        channel.handleRead(userData & ~TransportPayloadAll);
        continue;
      }

      if (userData & TransportPayloadWrite != 0) {
        channel.handleWrite(userData & ~TransportPayloadAll);
        continue;
      }
    }
  }

  void stop() => _bindings.transport_close(_transport);
}
