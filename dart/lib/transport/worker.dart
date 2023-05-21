import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'bindings.dart';
import 'buffers.dart';
import 'callbacks.dart';
import 'client/factory.dart';
import 'client/registry.dart';
import 'constants.dart';
import 'file/factory.dart';
import 'file/registry.dart';
import 'links.dart';
import 'lookup.dart';
import 'payload.dart';
import 'server/factory.dart';
import 'server/registry.dart';
import 'timeout.dart';

class TransportWorker {
  final _fromTransport = ReceivePort();

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
  late final TransportCallbacks _callbacks;
  late final TransportLinks _links;
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
    _callbacks = TransportCallbacks(
      _workerPointer.ref.buffers_count,
    );
    _links = TransportLinks(
      _workerPointer.ref.buffers_count,
    );
    _payloadPool = TransportPayloadPool(_workerPointer.ref.buffers_count, _buffers);
    _clientRegistry = TransportClientRegistry(
      _bindings,
      _callbacks,
      _workerPointer,
      _buffers,
      _payloadPool,
      _links,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _callbacks,
      _workerPointer,
      _buffers,
      _payloadPool,
      _links,
    );
    _serversFactory = TransportServersFactory(
      _serverRegistry,
    );
    _clientsFactory = TransportClientsFactory(
      _clientRegistry,
    );
    _filesRegistry = TransportFileRegistry(
      _bindings,
      _callbacks,
      _workerPointer,
      _buffers,
      _payloadPool,
      _links,
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
  void registerCallback(int id, Completer<int> completer) => _callbacks.setCustom(id, completer);

  @pragma(preferInlinePragma)
  void removeCallback(int id) => _callbacks.removeCustom(id);

  @pragma(preferInlinePragma)
  void submit() => _bindings.transport_worker_submit(_workerPointer);

  Future<void> _listen() async {
    final delayFactor = _workerPointer.ref.delay_factor;
    final randomizationFactor = _workerPointer.ref.randomization_factor;
    final maxDelay = _workerPointer.ref.max_delay;
    final maxActiveTime = _workerPointer.ref.max_active_time;
    final random = Random();
    var attempt = 0;
    var delayTimestamp = Timeline.now;
    final regularDelayDuration = Duration(microseconds: delayFactor);
    while (true) {
      attempt++;
      submit();
      if (_handleCqes()) {
        attempt = 0;
        if (Timeline.now - delayTimestamp > maxActiveTime) {
          _bindings.transport_notify_idle(Timeline.now + delayFactor);
          await Future.delayed(regularDelayDuration);
          delayTimestamp = Timeline.now;
        }
        continue;
      }
      final randomization = (randomizationFactor * (random.nextDouble() * 2 - 1) + 1);
      final exponent = min(attempt, 31);
      final delay = (delayFactor * pow(2.0, exponent) * randomization).toInt();
      await Future.delayed(Duration(microseconds: delay < maxDelay ? delay : maxDelay));
    }
  }

  bool _handleCqes() {
    final cqeCount = _bindings.transport_worker_peek(_ringSize, _cqes, _workerPointer);
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
      if (event & transportEventLink != 0) {
        event &= ~transportEventLink;
        _buffers.setLength(bufferId, result);
        if (bufferId != _links.get(bufferId)) continue;
      }
      if (event & transportEventClient != 0) {
        event &= ~transportEventClient;
        if (event == transportEventConnect) {
          _handleConnect(fd, result);
          continue;
        }
        _handleClientData(event, bufferId, result, fd);
      }
      if (event & transportEventFile != 0) {
        _handleFile(event = event & ~transportEventFile, bufferId, result, fd);
        continue;
      }
      if (event & transportEventServer != 0) {
        event &= ~transportEventServer;
        if (event == transportEventAccept) {
          _handleAccept(fd, result);
          continue;
        }
        if (event == transportEventRead || event == transportEventWrite) {
          _handleServerConnection(bufferId, fd, result, event);
          continue;
        }
        _handleServerDatagram(bufferId, fd, result, event);
      }
    }
    _bindings.transport_cqe_advance(_ring, cqeCount);
    return true;
  }

  @pragma(preferInlinePragma)
  void _handleServerConnection(int bufferId, int fd, int result, int event) => _serverRegistry.getConnection(fd)?.notify(bufferId, result, event);

  @pragma(preferInlinePragma)
  void _handleServerDatagram(int bufferId, int fd, int result, int event) => _serverRegistry.getByServer(fd)?.notifyDatagram(bufferId, result, event);

  @pragma(preferInlinePragma)
  void _handleClientData(int event, int bufferId, int result, int fd) => _clientRegistry.get(fd)?.notifyData(bufferId, result, event);

  @pragma(preferInlinePragma)
  void _handleFile(int event, int bufferId, int result, int fd) => _filesRegistry.get(fd)?.notify(bufferId, result, fd);

  @pragma(preferInlinePragma)
  void _handleConnect(int fd, int result) => _clientRegistry.get(fd)?.notifyConnect(fd, result);

  @pragma(preferInlinePragma)
  void _handleAccept(int fd, int result) => _serverRegistry.getByServer(fd)?.notifyAccept(result);

  @visibleForTesting
  void notifyCustom(int id, int data) {
    _bindings.transport_worker_custom(_workerPointer, id, data);
  }

  @visibleForTesting
  TransportBuffers get buffers => _buffers;
}
