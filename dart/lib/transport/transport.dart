import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'constants.dart';
import 'extensions.dart';

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
  final _listenerPointers = <Pointer<transport_listener_t>>[];
  final _jobs = <String, int>{};
  final _jobRunners = <SendPort>[];

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transportPointer;
  late final RawReceivePort _jobListener;
  late final RawReceivePort _jobCompletionListener;

  Transport(this.transportConfiguration, this.listenerConfiguration, this.inboundWorkerConfiguration, this.outboundWrkerConfiguration, {String? libraryPath}) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

    final nativeListenerConfiguration = calloc<transport_listener_configuration_t>();
    nativeListenerConfiguration.ref.ring_flags = listenerConfiguration.ringFlags;
    nativeListenerConfiguration.ref.ring_size = listenerConfiguration.ringSize;
    nativeListenerConfiguration.ref.workers_count = transportConfiguration.workerInsolates;

    final nativeInboundWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeInboundWorkerConfiguration.ref.ring_flags = inboundWorkerConfiguration.ringFlags;
    nativeInboundWorkerConfiguration.ref.ring_size = inboundWorkerConfiguration.ringSize;
    nativeInboundWorkerConfiguration.ref.buffer_size = inboundWorkerConfiguration.bufferSize;
    nativeInboundWorkerConfiguration.ref.buffers_count = inboundWorkerConfiguration.buffersCount;
    nativeInboundWorkerConfiguration.ref.timeout_checker_period_millis = inboundWorkerConfiguration.timeoutCheckerPeriod.inMilliseconds;

    final nativeoOutboundWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeoOutboundWorkerConfiguration.ref.ring_flags = outboundWrkerConfiguration.ringFlags;
    nativeoOutboundWorkerConfiguration.ref.ring_size = outboundWrkerConfiguration.ringSize;
    nativeoOutboundWorkerConfiguration.ref.buffer_size = outboundWrkerConfiguration.bufferSize;
    nativeoOutboundWorkerConfiguration.ref.buffers_count = outboundWrkerConfiguration.buffersCount;
    nativeoOutboundWorkerConfiguration.ref.timeout_checker_period_millis = outboundWrkerConfiguration.timeoutCheckerPeriod.inMilliseconds;

    _transportPointer = calloc<transport_t>();
    if (_transportPointer == nullptr) {
      throw TransportInitializationException("[transport] out of memory");
    }
    _bindings.transport_initialize(
      _transportPointer,
      nativeListenerConfiguration,
      nativeInboundWorkerConfiguration,
      nativeoOutboundWorkerConfiguration,
    );
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    _workerClosers.forEach((worker) => worker.send(gracefulDuration));
    await _workerExit.take(transportConfiguration.workerInsolates).toList();
    _workerExit.close();
    _jobListener.close();
    _jobCompletionListener.close();

    _listenerPointers.forEach((listener) => _bindings.transport_listener_close(listener));
    await _listenerExit.take(transportConfiguration.listenerIsolates).toList();
    _listenerExit.close();

    _bindings.transport_destroy(_transportPointer);
  }

  Future<void> run(void Function(SendPort input) worker, {SendPort? transmitter}) async {
    _jobListener = RawReceivePort((input) {
      final job = input[0];
      final index = input[1];
      final current = _jobs[job];
      if (current == null) {
        _jobs[job] = index;
        _jobRunners[index].send([job, true]);
        return;
      }
      _jobRunners[index].send([job, current == index]);
    });
    _jobCompletionListener = RawReceivePort((job) => _jobs.remove(job));
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
      _jobRunners.add(ports[4]);
      final inboundWorkerPointer = calloc<transport_worker_t>();
      if (inboundWorkerPointer == nullptr) {
        workersCompleter.completeError(TransportInitializationException("[worker] out of memory"));
        fromTransportToWorker.close();
        return;
      }
      var result = _bindings.transport_worker_initialize(
        inboundWorkerPointer,
        _transportPointer.ref.inbound_worker_configuration,
        inboundWorkerAddresses.length,
      );
      if (result < 0) {
        calloc.free(inboundWorkerPointer);
        workersCompleter.completeError(TransportInitializationException("[worker] code = $result, message = ${result.kernelErrorToString(_bindings)}"));
        fromTransportToWorker.close();
        return;
      }
      inboundWorkerAddresses.add(inboundWorkerPointer.address);
      final outboundWorkerPointer = calloc<transport_worker_t>();
      if (outboundWorkerPointer == nullptr) {
        workersCompleter.completeError(TransportInitializationException("[worker] out of memory"));
        fromTransportToWorker.close();
        return;
      }
      result = _bindings.transport_worker_initialize(
        outboundWorkerPointer,
        _transportPointer.ref.outbound_worker_configuration,
        outboundWorkerAddresses.length,
      );
      if (result < 0) {
        _bindings.transport_worker_destroy(inboundWorkerPointer);
        calloc.free(outboundWorkerPointer);
        workersCompleter.completeError(TransportInitializationException("[worker] code = $result, message = ${result.kernelErrorToString(_bindings)}"));
        fromTransportToWorker.close();
        return;
      }
      outboundWorkerAddresses.add(outboundWorkerPointer.address);
      final workerInput = [
        _libraryPath,
        _transportPointer.address,
        inboundWorkerPointer.address,
        outboundWorkerPointer.address,
        transmitter,
        _jobListener.sendPort,
        _jobCompletionListener.sendPort,
      ];
      toWorker.send(workerInput);
      if (inboundWorkerAddresses.length == transportConfiguration.workerInsolates) {
        fromTransportToWorker.close();
        workersCompleter.complete();
      }
    });

    fromTransportToListener.listen((port) async {
      await workersCompleter.future.onError((error, stackTrace) {
        listenerCompleter.completeError(error!, stackTrace);
        fromTransportToListener.close();
        throw error;
      });
      final listenerPointer = calloc<transport_listener_t>();
      if (listenerPointer == nullptr) {
        listenerCompleter.completeError(TransportInitializationException("[listener] out of memory"));
        fromTransportToListener.close();
        return;
      }
      var result = _bindings.transport_listener_initialize(listenerPointer, _transportPointer.ref.listener_configuration, listeners);
      if (result < 0) {
        calloc.free(listenerPointer);
        for (var workerIndex = 0; workerIndex < transportConfiguration.workerInsolates; workerIndex++) {
          final inboundWorker = Pointer.fromAddress(inboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
          final outboundWorker = Pointer.fromAddress(outboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
          _bindings.transport_worker_destroy(inboundWorker);
          _bindings.transport_worker_destroy(outboundWorker);
        }
        listenerCompleter.completeError(TransportInitializationException("[listener] code = $result, message = ${result.kernelErrorToString(_bindings)}"));
        fromTransportToListener.close();
        return;
      }
      _listenerPointers.add(listenerPointer);
      for (var workerIndex = 0; workerIndex < transportConfiguration.workerInsolates; workerIndex++) {
        final inboundWorker = Pointer.fromAddress(inboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
        final outboundWorker = Pointer.fromAddress(outboundWorkerAddresses[workerIndex]).cast<transport_worker_t>();
        if (_listenerPointers.length == 1) {
          _bindings.transport_worker_initialize_listeners(inboundWorker, listenerPointer);
          _bindings.transport_worker_initialize_listeners(outboundWorker, listenerPointer);
          continue;
        }
        _bindings.transport_worker_add_listener(inboundWorker, listenerPointer);
        _bindings.transport_worker_add_listener(outboundWorker, listenerPointer);
      }
      (port as SendPort).send([
        _libraryPath,
        listenerPointer.address,
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
        debugName: "worker-$isolate",
      );
    }

    for (var isolate = 0; isolate < transportConfiguration.listenerIsolates; isolate++) {
      Isolate.spawn<SendPort>(
        (toTransport) => TransportListener(toTransport).initialize(),
        fromTransportToListener.sendPort,
        onExit: _listenerExit.sendPort,
        debugName: "listener-$isolate",
      );
    }

    try {
      await listenerCompleter.future;
    } catch (_) {
      _bindings.transport_destroy(_transportPointer);
      rethrow;
    }
    workerActivators.forEach((port) => port.send(null));
  }
}
