import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/state.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'client.dart';
import 'communicator.dart';
import 'configuration.dart';
import 'file.dart';
import 'payload.dart';
import 'server.dart';
import 'worker.dart';

class TransportServersFactory {
  final TransportServerRegistry _registry;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportServersFactory(
    this._registry,
    this._workerPointer,
    this._bindings,
    this._bufferFinalizers,
  );

  Stream<TransportServerStreamCommunicator> tcp(
    String host,
    int port, {
    TransportTcpServerConfiguration? configuration,
  }) {
    final server = _registry.createTcp(host, port, configuration: configuration);
    return server.accept(_workerPointer);
  }

  TransportServerDatagramCommunicator udp(
    String host,
    int port,
  ) {
    final server = _registry.createUdp(host, port);
    return TransportServerDatagramCommunicator(
      server,
      TransportChannel(
        _workerPointer,
        server.pointer.ref.fd,
        _bindings,
        _bufferFinalizers,
      ),
    );
  }

  Stream<TransportServerStreamCommunicator> unixStream(
    String path,
  ) {
    final server = _registry.createUnixStream(path);
    return server.accept(_workerPointer);
  }

  TransportServerDatagramCommunicator unixDatagram(
    String path,
  ) {
    final server = _registry.createUnixDatagram(path);
    return TransportServerDatagramCommunicator(
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

  TransportClientsFactory(
    this._registry,
  );

  Future<TransportClientCommunicators> tcp(String host, int port, {TransportTcpClientConfiguration? configuration}) => _registry.createTcp(host, port, configuration: configuration);

  TransportClientCommunicator udp(String sourceHost, int sourcePort, String destinationHost, int destinationPort, {TransportUdpClientConfiguration? configuration}) => _registry.createUdp(
        sourceHost,
        sourcePort,
        destinationHost,
        destinationPort,
        configuration: configuration,
      );

  Future<TransportClientCommunicators> unixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) => _registry.createUnixStream(path, configuration: configuration);

  TransportClientCommunicator unixDatagram(String sourcePath, String destinationPath, {TransportUnixDatagramClientConfiguration? configuration}) => _registry.createUnixDatagram(
        sourcePath,
        destinationPath,
        configuration: configuration,
      );
}

class TransportFilesFactory {
  final TransportEventStates _eventStates;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportWorker _worker;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportFilesFactory(
    this._workerPointer,
    this._bindings,
    this._worker,
    this._bufferFinalizers,
    this._eventStates,
  );

  TransportFile open(String path) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_eventStates, TransportChannel(_workerPointer, fd, _bindings, _bufferFinalizers));
  }
}
