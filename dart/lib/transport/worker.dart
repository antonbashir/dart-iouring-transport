import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'bindings.dart';
import 'buffers.dart';
import 'client/factory.dart';
import 'client/registry.dart';
import 'constants.dart';
import 'file/factory.dart';
import 'file/registry.dart';
import 'lookup.dart';
import 'payload.dart';
import 'server/factory.dart';
import 'server/registry.dart';
import 'timeout.dart';

final cqeWaitCount = List.generate(16, (index) => 128 * (index + 1));

class TransportWorker {
  final _fromTransport = ReceivePort();
  final _customCallbacks = <int, Completer<int>>{};

  late final TransportBindings _bindings;
  late final Pointer<transport_worker_t> _workerPointer;
  late final Pointer<io_uring> _ring;
  late final Pointer<Pointer<io_uring_cqe>> _cqes;
  late final RawReceivePort _closer;
  late final SendPort _destroyer;
  late final TransportClientRegistry _clientRegistry;
  late final TransportServerRegistry _serverRegistry;
  late final TransportClientsFactory _clientsFactory;
  late final TransportServersFactory _serversFactory;
  late final TransportFileRegistry _filesRegistry;
  late final TransportFilesFactory _filesFactory;
  late final int _ringSize;
  late final TransportBuffers _buffers;
  late final TransportTimeoutChecker _timeoutChecker;
  late final TransportPayloadPool _payloadPool;

  int get id => _workerPointer.ref.id;
  int get descriptor => _ring.ref.ring_fd;
  TransportServersFactory get servers => _serversFactory;
  TransportClientsFactory get clients => _clientsFactory;
  TransportFilesFactory get files => _filesFactory;

  TransportWorker(SendPort toTransport) {
    _closer = RawReceivePort((gracefulDuration) async {
      _timeoutChecker.stop();
      await _filesRegistry.close(gracefulDuration: gracefulDuration);
      await _clientRegistry.close(gracefulDuration: gracefulDuration);
      await _serverRegistry.close(gracefulDuration: gracefulDuration);
      _bindings.transport_worker_destroy(_workerPointer);
      malloc.free(_cqes);
      _closer.close();
      _destroyer.send(null);
    });
    toTransport.send([_fromTransport.sendPort, _closer.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _workerPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_worker_t>();
    _destroyer = configuration[2] as SendPort;
    _fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _buffers = TransportBuffers(
      _bindings,
      _workerPointer.ref.buffers,
      _workerPointer,
    );
    _payloadPool = TransportPayloadPool(_workerPointer.ref.buffers_count, _buffers);
    _clientRegistry = TransportClientRegistry(
      _bindings,
      _workerPointer,
      _buffers,
      _payloadPool,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _workerPointer,
      _buffers,
      _payloadPool,
    );
    _serversFactory = TransportServersFactory(
      _serverRegistry,
    );
    _clientsFactory = TransportClientsFactory(
      _clientRegistry,
    );
    _filesRegistry = TransportFileRegistry(
      _bindings,
      _workerPointer,
      _buffers,
      _payloadPool,
    );
    _filesFactory = TransportFilesFactory(_filesRegistry);
    _ring = _workerPointer.ref.ring;
    _cqes = _bindings.transport_allocate_cqes(_workerPointer.ref.ring_size);
    _ringSize = _workerPointer.ref.ring_size;
    _timeoutChecker = TransportTimeoutChecker(
      _bindings,
      _workerPointer,
      Duration(milliseconds: _workerPointer.ref.timeout_checker_period_millis),
    );
    _timeoutChecker.start();
    _listen();
  }

  @pragma(preferInlinePragma)
  void registerCallback(int id, Completer<int> completer) => _customCallbacks[id] = completer;

  @pragma(preferInlinePragma)
  void removeCallback(int id) => _customCallbacks.remove(id);

  @pragma(preferInlinePragma)
  void submit() => _bindings.transport_worker_submit(_workerPointer);

  Future<void> _listen() async {
    final delayFactor = _workerPointer.ref.delay_factor;
    final randomizationFactor = _workerPointer.ref.randomization_factor;
    final maxDelay = _workerPointer.ref.max_delay;
    final random = Random();
    var attempt = 0;
    final regularDelayDuration = Duration(microseconds: delayFactor);
    while (true) {
      attempt = min(attempt++, cqeWaitCount.length);
      if (_handleCqes(attempt)) {
        attempt = 0;
        await Future.delayed(regularDelayDuration);
        continue;
      }
      final randomization = (randomizationFactor * (random.nextDouble() * 2 - 1) + 1);
      final exponent = min(attempt, 31);
      final delay = (delayFactor * pow(2.0, exponent) * randomization).toInt();
      await Future.delayed(Duration(microseconds: delay < maxDelay ? delay : maxDelay));
    }
  }

  bool _handleCqes(int attempt) {
    final cqeCount = _bindings.transport_worker_peek(cqeWaitCount[attempt], _cqes, _workerPointer);
    if (cqeCount <= 0) return false;
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _cqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      var event = data & 0xffff;
      _bindings.transport_worker_remove_event(_workerPointer, data);
      final fd = (data >> 32) & 0xffffffff;
      //print("${TransportEvent.ofEvent(event)} worker = ${_workerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      final bufferId = (data >> 16) & 0xffff;
      if (event & transportEventClient != 0) {
        event &= ~transportEventClient;
        if (event == transportEventConnect) {
          _clientRegistry.get(fd)?.notifyConnect(fd, result);
          continue;
        }
        _clientRegistry.get(fd)?.notifyData(bufferId, result, event);
        continue;
      }
      if (event & transportEventServer != 0) {
        event &= ~transportEventServer;
        if (event == transportEventAccept) {
          _serverRegistry.getByServer(fd)?.notifyAccept(result);
          continue;
        }
        if (event == transportEventRead || event == transportEventWrite) {
          _serverRegistry.getConnection(fd)?.notify(bufferId, result, event);
          continue;
        }
        _serverRegistry.getByServer(fd)?.notifyDatagram(bufferId, result, event);
      }
      if (event & transportEventFile != 0) {
        _filesRegistry.get(fd)?.notify(bufferId, result, fd);
        continue;
      }
      if (event & transportEventCustom != 0) {
        _customCallbacks.remove(result)?.complete(data & ~transportEventCustom);
      }
    }
    _bindings.transport_cqe_advance(_ring, cqeCount);
    return true;
  }

  @visibleForTesting
  void notifyCustom(int id, int data) => _bindings.transport_worker_custom(_workerPointer, id, data);

  @visibleForTesting
  TransportBuffers get buffers => _buffers;
}
