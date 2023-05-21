import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../extensions.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'provider.dart';
import 'registry.dart';

class TransportClient {
  final _connector = Completer();
  final StreamController<TransportPayload> _inboundEvents = StreamController();
  final StreamController<void> _outboundEvents = StreamController();
  final Pointer<transport_client_t> _pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportChannel _channel;
  final TransportBindings _bindings;
  final int? _connectTimeout;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportBuffers _buffers;
  final TransportClientRegistry _registry;
  final TransportPayloadPool _payloadPool;

  late final Pointer<sockaddr> _destination;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportClient(
    this._channel,
    this._pointer,
    this._workerPointer,
    this._bindings,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry,
    this._payloadPool, {
    int? connectTimeout,
  }) : _connectTimeout = connectTimeout {
    _destination = _bindings.transport_client_get_destination_address(_pointer);
  }

  Stream<TransportPayload> get inbound => _inboundEvents.stream;
  Stream<void> get outbound => _outboundEvents.stream;

  Future<void> read() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
  }

  Future<void> writeSingle(Uint8List bytes) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    _channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
  }

  Future<void> writeMany(List<Uint8List> bytes) async {
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forClient();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      _channel.write(
        bytes[index],
        bufferIds[index],
        _writeTimeout,
        transportEventWrite | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    _channel.write(
      bytes.last,
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventClient | transportEventLink,
    );
    _pending += bytes.length;
  }

  Future<void> receiveSingleMessage({bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    _channel.receiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
  }

  Future<void> receiveManyMessages(int count, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forClient();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _channel.receiveMessage(
        bufferId,
        _pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    _channel.receiveMessage(
      lastBufferId,
      _pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventClient | transportEventLink,
    );
    _pending += count;
  }

  Future<void> sendSingleMessage(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    _channel.sendMessage(
      bytes,
      bufferId,
      _pointer.ref.family,
      _destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
  }

  Future<void> sendManyMessages(List<Uint8List> bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _channel.sendMessage(
        bytes[index],
        bufferId,
        _pointer.ref.family,
        _destination,
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    _channel.sendMessage(
      bytes.last,
      lastBufferId,
      _pointer.ref.family,
      _destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient | transportEventLink,
    );
    _pending += bytes.length;
  }

  Future<TransportClient> connect() async {
    if (_closing) throw TransportClosedException.forClient();
    _bindings.transport_worker_connect(_workerPointer, _pointer, _connectTimeout!);
    _pending++;
    return _connector.future.then((value) => this);
  }

  void notifyConnect(int fd, int result) {
    _pending--;
    if (_active) {
      if (result == 0) {
        _connector.complete();
        return;
      }
      if (result == -ECANCELED) {
        _connector.completeError(TransportCanceledException(event: TransportEvent.connect));
        return;
      }
      _connector.completeError(
        TransportInternalException(
          event: TransportEvent.connect,
          code: result,
          message: result.kernelErrorToString(_bindings),
        ),
      );
      return;
    }
    _connector.completeError(TransportClosedException.forClient());
    if (_pending == 0) _closer.complete();
  }

  void notifyData(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event.isReadEvent()) {
        if (result > 0) {
          _buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
          return;
        }
        _buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.ofEvent(event), result, _bindings));
        return;
      }
      if (result > 0) {
        _buffers.release(bufferId);
        return;
      }
      _outboundEvents.addError(createTransportException(
        TransportEvent.ofEvent(event),
        result,
        _bindings,
        payload: _payloadPool.getPayload(bufferId, _buffers.read(bufferId)),
      ));
      return;
    }
    _buffers.release(bufferId);
    event.isReadEvent() ? _inboundEvents.addError(TransportClosedException.forClient()) : _outboundEvents.addError(TransportClosedException.forClient());
    if (_pending == 0) _closer.complete();
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    await _inboundEvents.close();
    await _outboundEvents.close();
    _channel.close();
    _registry.remove(_pointer.ref.fd);
    _bindings.transport_client_destroy(_pointer);
  }

  @visibleForTesting
  TransportClientRegistry get registry => _registry;
}

class TransportClientStreamPool {
  final List<TransportClientStreamProvider> _clients;
  var _next = 0;

  List<TransportClientStreamProvider> get clients => _clients;

  TransportClientStreamPool(this._clients);

  @pragma(preferInlinePragma)
  TransportClientStreamProvider select() {
    final provider = _clients[_next];
    if (++_next == _clients.length) _next = 0;
    return provider;
  }

  @pragma(preferInlinePragma)
  void forEach(FutureOr<void> Function(TransportClientStreamProvider provider) action) => _clients.forEach(action);

  @pragma(preferInlinePragma)
  Iterable<Future<M>> map<M>(Future<M> Function(TransportClientStreamProvider provider) mapper) => _clients.map(mapper);

  @pragma(preferInlinePragma)
  int count() => _clients.length;

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_clients.map((provider) => provider.close(gracefulDuration: gracefulDuration)));
}
