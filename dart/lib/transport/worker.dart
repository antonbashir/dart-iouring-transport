import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'bindings.dart';
import 'channels/channel.dart';
import 'constants.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportWorker {
  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

  final fromTransport = ReceivePort();

  TransportWorker(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> handle({
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
    final channelPointer = _bindings.transport_activate_channel(_transport);
    final ring = channelPointer.ref.ring;
    final channel = TransportChannel.fromPointer(
      channelPointer,
      _bindings,
      onRead: onRead,
      onWrite: onWrite,
      onStop: onStop,
    );
    final futures = <Future>[];
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_transport);
    while (true) {
      int cqeCount = _bindings.transport_consume(_transport, cqes, ring);
      if (cqeCount == -1) continue;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final int result = cqe.ref.res;
        final int userData = cqe.ref.user_data;

        if (result < 0) {
          continue;
        }

        if (userData & TransportPayloadRead != 0) {
          final fd = userData & ~TransportPayloadAll;
          final bufferId = _bindings.transport_channel_handle_read(channel.channel, cqe, fd);
          futures.add(channel.handleRead(fd, bufferId));
          continue;
        }

        if (userData & TransportPayloadWrite != 0) {
          final fd = userData & ~TransportPayloadAll;
          final bufferId = _bindings.transport_channel_handle_write(channel.channel, cqe, fd);
          futures.add(channel.handleWrite(fd, bufferId));
          continue;
        }

        if (userData & TransportPayloadMessage != 0) {
          futures.add(channel.read(result));
          continue;
        }
      }
      
      _bindings.transport_cqe_advance(ring, cqeCount);
      await Future.wait(futures);
      futures.clear();
    }
  }

  Future<void> accept() async {
    final configuration = await fromTransport.take(2).toList();
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    final _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    final acceptor = _bindings.transport_activate_acceptor(_transport);
    _bindings.transport_accept(_transport, acceptor.ref.ring);
  }

  void stop() => _bindings.transport_close(_transport);
}
