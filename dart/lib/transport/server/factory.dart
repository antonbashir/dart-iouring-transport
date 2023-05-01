import 'dart:ffi';
import 'dart:io';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import 'configuration.dart';
import 'connection.dart';
import 'datagram.dart';
import 'registry.dart';
import 'server.dart';
import 'package:meta/meta.dart';

class TransportServersFactory {
  final TransportBindings _bindings;
  final TransportServerRegistry _registry;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;

  @visibleForTesting
  TransportServerRegistry get registry => _registry;

  TransportServersFactory(
    this._bindings,
    this._registry,
    this._workerPointer,
    this._buffers,
  );

  TransportServerCloser tcp(InternetAddress address, int port, void Function(TransportServerConnection connection) onAccept, {TransportTcpServerConfiguration? configuration}) =>
      _registry.createTcp(address.address, port, configuration: configuration)..accept(onAccept);

  TransportServerDatagramReceiver udp(InternetAddress address, int port, {TransportUdpServerConfiguration? configuration}) {
    final server = _registry.createUdp(address.address, port, configuration: configuration);
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

  TransportServerCloser unixStream(String path, void Function(TransportServerConnection connection) onAccept, {TransportUnixStreamServerConfiguration? configuration}) =>
      _registry.createUnixStream(path, configuration: configuration)..accept(onAccept);

  TransportServerDatagramReceiver unixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    final server = _registry.createUnixDatagram(path, configuration: configuration);
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
