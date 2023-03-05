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
    final futures = <Future>[];
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_transport);
    while (true) {
      cqes = _bindings.transport_consume(_transport, cqes, ring);
      if (cqes == nullptr) continue;
      int cqeCount = _bindings.transport_cqe_ready(ring);
      int cqeProcessed = 0;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        if (cqe == nullptr) {
          continue;
        }
        cqeProcessed++;
        final int result = cqe.ref.res;
        final int userData = cqe.ref.user_data;

        if (result < 0) {
          _bindings.transport_acceptor_accept(_transport.ref.acceptor);
          continue;
        }

        if (userData & TransportPayloadAccept != 0) {
          _bindings.transport_acceptor_accept(_transport.ref.acceptor);
          futures.add(channel.read(result));
          continue;
        }

        final fd = userData & ~TransportPayloadAll;

        if (userData & TransportPayloadRead != 0) {
          final bufferId = _bindings.transport_channel_handle_read(channel.channel, cqe, fd);
          futures.add(channel.handleRead(fd, bufferId));
          continue;
        }

        if (userData & TransportPayloadWrite != 0) {
          final bufferId = _bindings.transport_channel_handle_write(channel.channel, cqe, fd);
          futures.add(channel.handleWrite(fd, bufferId));
          continue;
        }
      }
      _bindings.transport_cqe_seen(ring, cqeProcessed);
      await Future.wait(futures);
      futures.clear();
    }
  }

  void stop() => _bindings.transport_close(_transport);
}
