import 'dart:ffi';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import 'configuration.dart';
import 'connection.dart';
import 'datagram.dart';
import 'registry.dart';

class TransportServersFactory {
  final TransportBindings _bindings;
  final TransportServerRegistry _registry;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;

  TransportServersFactory(
    this._bindings,
    this._registry,
    this._workerPointer,
    this._buffers,
  );

  void tcp(String host, int port, void Function(TransportServerConnection connection) onAccept, {TransportTcpServerConfiguration? configuration}) {
    _registry.createTcp(host, port, configuration: configuration).accept(onAccept);
  }

  TransportServerDatagramReceiver udp(String host, int port) {
    final server = _registry.createUdp(host, port);
    return TransportServerDatagramReceiver(
      server,
      TransportChannel(
        _workerPointer,
        server.pointer.ref.fd,
        _bindings,
        _buffers,
      ),
    );
  }

  void unixStream(String path, void Function(TransportServerConnection communicator) onAccept) {
    _registry.createUnixStream(path).accept(onAccept);
  }

  TransportServerDatagramReceiver unixDatagram(String path) {
    final server = _registry.createUnixDatagram(path);
    return TransportServerDatagramReceiver(
      server,
      TransportChannel(
        _workerPointer,
        server.pointer.ref.fd,
        _bindings,
        _buffers,
      ),
    );
  }
}
