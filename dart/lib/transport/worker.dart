import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'constants.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportWorker {
  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

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
    final channelPointer = _bindings.transport_add_channel(_transport);
    final ring = channelPointer.ref.ring;
    final channel = TransportChannel(
      channelPointer,
      _bindings,
      onRead: onRead,
      onWrite: onWrite,
      onStop: onStop,
    );
    Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_allocate_cqes(_transport);
    while (true) {
      int cqeCount = _bindings.transport_consume(_transport, cqes, ring);
      if (cqeCount == -1) continue;
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final int result = cqe.ref.res;
        final int userData = cqe.ref.user_data;
        if (result < 0) {
          print("transport channel error cqe with result $result and user_data $userData");
          continue;
        }
        if (userData & TransportPayloadRead != 0) {
          channel.handleRead(userData & ~TransportPayloadAll, result);
          continue;
        }
        if (userData & TransportPayloadWrite != 0) {
          channel.handleWrite(userData & ~TransportPayloadAll, result);
          continue;
        }
        if (userData & TransportPayloadMessage != 0) {
          await channel.read(result);
          continue;
        }
      }
      _bindings.transport_cqe_advance(ring, cqeCount);
    }
  }

  Future<void> accept() async {
    final configuration = await fromTransport.take(4).toList();
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    String host = configuration[2] as String;
    int port = configuration[3] as int;
    final _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    using((Arena arena) {
      _bindings.transport_accept(_transport, host.toNativeUtf8(allocator: arena).cast(), port);
    });
  }

  void stop() => _bindings.transport_close(_transport);
}
