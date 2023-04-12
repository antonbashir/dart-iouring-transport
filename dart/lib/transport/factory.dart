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
import 'state.dart';
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

  Stream<TransportServerStreamCommunicator> unixStream(
    String path,
  ) {
    final server = _registry.createUnixStream(path);
    return server.accept(_workerPointer);
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

  TransportClientsFactory(
    this._registry,
  );

  Future<TransportClientStreamCommunicators> tcp(String host, int port, {TransportTcpClientConfiguration? configuration}) => _registry.createTcp(host, port, configuration: configuration);

  TransportClientDatagramCommunicator udp(String sourceHost, int sourcePort, String destinationHost, int destinationPort, {TransportUdpClientConfiguration? configuration}) => _registry.createUdp(
        sourceHost,
        sourcePort,
        destinationHost,
        destinationPort,
        configuration: configuration,
      );

  Future<TransportClientStreamCommunicators> unixStream(String path, {TransportUnixStreamClientConfiguration? configuration}) => _registry.createUnixStream(path, configuration: configuration);

  TransportClientDatagramCommunicator unixDatagram(String sourcePath, String destinationPath, {TransportUnixDatagramClientConfiguration? configuration}) => _registry.createUnixDatagram(
        sourcePath,
        destinationPath,
        configuration: configuration,
      );
}

class TransportFilesFactory {
  final Transportcallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportWorker _worker;
  final Queue<Completer<int>> _bufferFinalizers;

  TransportFilesFactory(
    this._workerPointer,
    this._bindings,
    this._worker,
    this._bufferFinalizers,
    this._callbacks,
  );

  TransportFile open(String path) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(_callbacks, TransportChannel(_workerPointer, fd, _bindings, _bufferFinalizers));
  }
}
