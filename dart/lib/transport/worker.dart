import 'dart:io';
import 'dart:isolate';

import 'dart:ffi';

import 'package:iouring_transport/transport/payload.dart';

import 'acceptor.dart';
import 'bindings.dart';
import 'channels/channel.dart';
import 'lookup.dart';

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
    final acceptor = TransportAcceptor.fromPointer(
      _transport.ref.acceptor,
      _bindings,
    );
    final channel = TransportChannel.fromPointer(
      _transport.ref.channel,
      _bindings,
      onRead: onRead,
      onWrite: onWrite,
      onStop: onStop,
    );
    acceptor.accept();
    while (true) {
      int result = _bindings.transport_consume(_transport);
      if (result < 0) {
        print("cqe error: $result");
        continue;
      }
      if (result & TRANSPORT_ACTION_ACCEPT == 1) {
        channel.handleAccept(result & ~_bindings.TRANSPORT_PAYLOAD_ALL_FLAGS);
        continue;
      }
      if (result & TRANSPORT_ACTION_READ == 1) {
        channel.handleRead(result & ~_bindings.TRANSPORT_PAYLOAD_ALL_FLAGS);
        continue;
      }
      if (result & TRANSPORT_ACTION_WRITE == 1) {
        channel.handleWrite(result & ~_bindings.TRANSPORT_PAYLOAD_ALL_FLAGS);
        continue;
      }
    }
  }

  void stop() => _bindings.transport_close(_transport);
}
