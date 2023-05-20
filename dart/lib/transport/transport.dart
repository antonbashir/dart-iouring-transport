import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'exception.dart';
import 'extensions.dart';
import 'lookup.dart';

class Transport {
  final TransportConfiguration transportConfiguration;
  final TransportWorkerConfiguration inboundWorkerConfiguration;
  final TransportWorkerConfiguration outboundWrkerConfiguration;

  final _workerExit = ReceivePort();
  final _workerClosers = <SendPort>[];
  final _jobs = <String, int>{};
  final _jobRunners = <SendPort>[];

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transportPointer;
  late final RawReceivePort _jobListener;
  late final RawReceivePort _jobCompletionListener;

  Transport(
    this.transportConfiguration,
    this.inboundWorkerConfiguration,
    this.outboundWrkerConfiguration, {
    String? libraryPath,
  }) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

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
      nativeInboundWorkerConfiguration,
      nativeoOutboundWorkerConfiguration,
    );
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    _workerClosers.forEach((worker) => worker.send(gracefulDuration));
    await _workerExit.take(transportConfiguration.workerIsolates).toList();
    _workerExit.close();

    _jobListener.close();
    _jobCompletionListener.close();
    _jobs.clear();
    _jobRunners.clear();

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
    _jobCompletionListener = RawReceivePort(_jobs.remove);
    final fromTransportToWorker = ReceivePort();
    final workersCompleter = Completer();
    final inboundWorkerAddresses = <int>[];
    final outboundWorkerAddresses = <int>[];
    final workerActivators = <SendPort>[];

    fromTransportToWorker.listen((ports) {
      SendPort toWorker = ports[0];
      workerActivators.add(ports[1]);
      _workerClosers.add(ports[2]);
      _jobRunners.add(ports[3]);
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
      if (inboundWorkerAddresses.length == transportConfiguration.workerIsolates) {
        fromTransportToWorker.close();
        workersCompleter.complete();
      }
    });

    for (var isolate = 0; isolate < transportConfiguration.workerIsolates; isolate++) {
      Isolate.spawn<SendPort>(
        worker,
        fromTransportToWorker.sendPort,
        onExit: _workerExit.sendPort,
        debugName: "worker-$isolate",
      );
    }

    try {
      await workersCompleter.future;
    } catch (_) {
      _bindings.transport_destroy(_transportPointer);
      rethrow;
    }
    workerActivators.forEach((port) => port.send(null));
  }
}
