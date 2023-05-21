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
  final _workerClosers = <SendPort>[];
  final _workerDestroyer = ReceivePort();

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;

  Transport({String? libraryPath}) {
    this._libraryPath = libraryPath;
    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    _workerClosers.forEach((worker) => worker.send(gracefulDuration));
    await _workerDestroyer.take(_workerClosers.length).toList();
  }

  SendPort worker(TransportWorkerConfiguration configuration) {
    final port = RawReceivePort((ports) {
      SendPort toWorker = ports[0];
      _workerClosers.add(ports[1]);
      final workerPointer = calloc<transport_worker_t>();
      if (workerPointer == nullptr) {
        throw TransportInitializationException("[worker] out of memory");
      }
      final nativeConfiguration = calloc<transport_worker_configuration_t>();
      nativeConfiguration.ref.ring_flags = configuration.ringFlags;
      nativeConfiguration.ref.ring_size = configuration.ringSize;
      nativeConfiguration.ref.buffer_size = configuration.bufferSize;
      nativeConfiguration.ref.buffers_count = configuration.buffersCount;
      nativeConfiguration.ref.timeout_checker_period_millis = configuration.timeoutCheckerPeriod.inMilliseconds;
      nativeConfiguration.ref.delay_factor = configuration.delayFactor.inMicroseconds;
      nativeConfiguration.ref.randomization_factor = configuration.randomizationFactor;
      nativeConfiguration.ref.max_active_time = configuration.maxActiveTime.inMicroseconds;
      nativeConfiguration.ref.max_delay = configuration.maxDelay.inMicroseconds;
      nativeConfiguration.ref.cqe_timeout_millis = configuration.cqeWaitTimeout.inMilliseconds;
      final result = _bindings.transport_worker_initialize(workerPointer, nativeConfiguration, _workerClosers.length);
      if (result < 0) {
        _bindings.transport_worker_destroy(workerPointer);
        throw TransportInitializationException("[worker] code = $result, message = ${result.kernelErrorToString(_bindings)}");
      }
      final workerInput = [_libraryPath, workerPointer.address, _workerDestroyer.sendPort];
      toWorker.send(workerInput);
    });
    return port.sendPort;
  }
}
