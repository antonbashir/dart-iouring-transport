import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'exception.dart';
import 'listener.dart';
import 'lookup.dart';

class Transport {
  final TransportConfiguration transportConfiguration;
  final TransportListenerConfiguration listenerConfiguration;
  final TransportWorkerConfiguration inboundWorkerConfiguration;
  final TransportWorkerConfiguration outboundWrkerConfiguration;

  final _listenerExit = ReceivePort();
  final _workerExit = ReceivePort();
  final _workerClosers = <SendPort>[];
  final _listenerClosers = <Pointer<transport_listener_t>>[];

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transportPointer;

  Transport(this.transportConfiguration, this.listenerConfiguration, this.inboundWorkerConfiguration, this.outboundWrkerConfiguration, {String? libraryPath}) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

    final nativeTransportConfiguration = calloc<transport_configuration_t>();
    nativeTransportConfiguration.ref.log_level = transportConfiguration.logLevel.index;

    final nativeListenerConfiguration = calloc<transport_listener_configuration_t>();
    nativeListenerConfiguration.ref.ring_flags = listenerConfiguration.ringFlags;
    nativeListenerConfiguration.ref.ring_size = listenerConfiguration.ringSize;
    nativeListenerConfiguration.ref.workers_count = transportConfiguration.workerInsolates;

    final nativeInboundWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeInboundWorkerConfiguration.ref.ring_flags = inboundWorkerConfiguration.ringFlags;
    nativeInboundWorkerConfiguration.ref.ring_size = inboundWorkerConfiguration.ringSize;
    nativeInboundWorkerConfiguration.ref.buffer_size = inboundWorkerConfiguration.bufferSize;
    nativeInboundWorkerConfiguration.ref.buffers_count = inboundWorkerConfiguration.buffersCount;

    final nativeoOutboundWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeoOutboundWorkerConfiguration.ref.ring_flags = outboundWrkerConfiguration.ringFlags;
    nativeoOutboundWorkerConfiguration.ref.ring_size = outboundWrkerConfiguration.ringSize;
    nativeoOutboundWorkerConfiguration.ref.buffer_size = outboundWrkerConfiguration.bufferSize;
    nativeoOutboundWorkerConfiguration.ref.buffers_count = outboundWrkerConfiguration.buffersCount;

    _transportPointer = _bindings.transport_initialize(
      nativeTransportConfiguration,
      nativeListenerConfiguration,
      nativeInboundWorkerConfiguration,
      nativeoOutboundWorkerConfiguration,
    );
  }

  Future<void> shutdown() async {
    _workerClosers.forEach((worker) => worker.send(null));
    await _workerExit.take(transportConfiguration.workerInsolates).toList();
    _listenerClosers.forEach((listener) => _bindings.transport_listener_close(listener));
    await _listenerExit.take(transportConfiguration.listenerIsolates).toList();
    _listenerExit.close();
    _bindings.transport_destroy(_transportPointer);
  }

  Future<void> run(void Function(SendPort input) worker, {SendPort? transmitter}) async {
    final fromTransportToListener = ReceivePort();
    final fromTransportToWorker = ReceivePort();
    var listeners = 0;
    final listenerCompleter = Completer();
    final workersCompleter = Completer();
    final inboundWorkerAddresses = <int>[];
    final outboundWorkerAddresses = <int>[];
    final workerMeessagePorts = <SendPort>[];
    final workerActivators = <SendPort>[];

    fromTransportToWorker.listen((ports) {
      SendPort toWorker = ports[0];
      workerMeessagePorts.add(ports[1]);
      workerActivators.add(ports[2]);
      _workerClosers.add(ports[3]);
      final inboundWorkerPointer = _bindings.transport_worker_initialize(_transportPointer.ref.inbound_worker_configuration, inboundWorkerAddresses.length);
      if (inboundWorkerPointer == nullptr) {
        final error = _bindings.transport_get_kernel_error();
        listenerCompleter.completeError(TransportException("[worker] is null, error = $error, message = ${error.kernelErrorToString(_bindings)}"));
        return;
      }
      inboundWorkerAddresses.add(inboundWorkerPointer.address);
      final outboundWorkerPointer = _bindings.transport_worker_initialize(_transportPointer.ref.outbound_worker_configuration, outboundWorkerAddresses.length);
      if (outboundWorkerPointer == nullptr) {
        final error = _bindings.transport_get_kernel_error();
        listenerCompleter.completeError(TransportException("[worker] is null, error = $error, message = ${error.kernelErrorToString(_bindings)}"));
        return;
      }
      outboundWorkerAddresses.add(outboundWorkerPointer.address);
      final workerInput = [
        _libraryPath,
        _transportPointer.address,
        inboundWorkerPointer.address,
        outboundWorkerPointer.address,
        transmitter,
      ];
      toWorker.send(workerInput);
      if (inboundWorkerAddresses.length == transportConfiguration.workerInsolates) {
        fromTransportToWorker.close();
        workersCompleter.complete();
      }
    });

    fromTransportToListener.listen((port) async {
      await workersCompleter.future;
      final listenerPointer = _bindings.transport_listener_initialize(_transportPointer.ref.listener_configuration, listeners);
      if (listenerPointer == nullptr) {
        final error = _bindings.transport_get_kernel_error();
        listenerCompleter.completeError(TransportException("[listener] is null, error = $error, message = ${error.kernelErrorToString(_bindings)}"));
        fromTransportToListener.close();
        return;
      }
      _listenerClosers.add(listenerPointer);
      for (var workerIndex = 0; workerIndex < transportConfiguration.workerInsolates; workerIndex++) {
        final inboundWorker = Pointer.fromAddress(inboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
        _bindings.transport_listener_pool_add(inboundWorker.ref.listeners, listenerPointer);
        final outboundWorker = Pointer.fromAddress(outboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
        _bindings.transport_listener_pool_add(outboundWorker.ref.listeners, listenerPointer);
      }
      (port as SendPort).send([
        _libraryPath,
        _transportPointer.address,
        listenerConfiguration.ringSize,
        workerMeessagePorts,
      ]);
      if (++listeners == transportConfiguration.listenerIsolates) {
        fromTransportToListener.close();
        listenerCompleter.complete();
      }
    });

    for (var isolate = 0; isolate < transportConfiguration.workerInsolates; isolate++) {
      Isolate.spawn<SendPort>(
        worker,
        fromTransportToWorker.sendPort,
        onExit: _workerExit.sendPort,
      );
    }

    for (var isolate = 0; isolate < transportConfiguration.listenerIsolates; isolate++) {
      Isolate.spawn<SendPort>(
        (toTransport) => TransportListener(toTransport).initialize(),
        fromTransportToListener.sendPort,
        onExit: _listenerExit.sendPort,
      );
    }

    await listenerCompleter.future;
    workerActivators.forEach((port) => port.send(null));
  }
}
