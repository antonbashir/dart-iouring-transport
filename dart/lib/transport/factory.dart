import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'channels.dart';
import 'client.dart';
import 'communicator.dart';
import 'configuration.dart';
import 'file.dart';
import 'server.dart';
import 'callbacks.dart';

class TransportServersFactory {
  final TransportBindings _bindings;
  final TransportServerRegistry _registry;
  final Pointer<transport_worker_t> _workerPointer;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportServersFactory(
    this._bindings,
    this._registry,
    this._workerPointer,
    this._bufferFinalizers,
  );

  void tcp(
    String host,
    int port,
    void Function(TransportServerConnection communicator) onAccept, {
    TransportTcpServerConfiguration? configuration,
  }) {
    final server = _registry.createTcp(host, port, configuration: configuration);
    server.accept(onAccept);
  }

  TransportServerDatagramReceiver udp(
    String host,
    int port,
  ) {
    final server = _registry.createUdp(host, port);
    return TransportServerDatagramReceiver(
      server,
      TransportChannel(
        _workerPointer,
        server.pointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
    );
  }

  void unixStream(
    String path,
    void Function(TransportServerConnection communicator) onAccept,
  ) {
    final server = _registry.createUnixStream(path);
    server.accept(onAccept);
  }

  TransportServerDatagramReceiver unixDatagram(
    String path,
  ) {
    final server = _registry.createUnixDatagram(path);
    return TransportServerDatagramReceiver(
      server,
      TransportChannel(
        _workerPointer,
        server.pointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
    );
  }
}

class TransportClientsFactory {
  final TransportClientRegistry _registry;

  TransportClientsFactory(this._registry);

  Future<TransportClientStreamCommunicators> tcp(String host, int port, {TransportTcpClientConfiguration? configuration}) => _registry.createTcp(host, port, configuration: configuration);

  TransportClientDatagramCommunicator udp(
    String sourceHost,
    int sourcePort,
    String destinationHost,
    int destinationPort, {
    TransportUdpClientConfiguration? configuration,
  }) =>
      _registry.createUdp(
        sourceHost,
        sourcePort,
        destinationHost,
        destinationPort,
        configuration: configuration,
      );

  Future<TransportClientStreamCommunicators> unixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) => _registry.createUnixStream(path, configuration: configuration);

  TransportClientDatagramCommunicator unixDatagram(
    String sourcePath,
    String destinationPath, {
    TransportUnixDatagramClientConfiguration? configuration,
  }) =>
      _registry.createUnixDatagram(
        sourcePath,
        destinationPath,
        configuration: configuration,
      );
}

class TransportFilesFactory {
  final TransportBindings _bindings;
  final Transportcallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportFilesFactory(
    this._bindings,
    this._callbacks,
    this._workerPointer,
    this._bufferFinalizers,
  );

  TransportFile open(String path) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportChannel(_workerPointer, fd, _bindings, _bufferFinalizers));
  }
}
