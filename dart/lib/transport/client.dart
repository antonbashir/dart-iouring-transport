import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'registry.dart';

import 'bindings.dart';
import 'buffers.dart';
import 'channels.dart';
import 'communicator.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';
import 'callbacks.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
  final Pointer<transport_client_t> _pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportChannel _channel;
  final TransportBindings _bindings;
  final int? _connectTimeout;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportBuffers buffers;
  final TransportClientRegistry _registry;

  late final String sourceAddress;
  late final String destinationAddress;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportClient(
    this._callbacks,
    this._channel,
    this._pointer,
    this._workerPointer,
    this._bindings,
    this._readTimeout,
    this._writeTimeout,
    this.buffers,
    this._registry, {
    int? connectTimeout,
  }) : _connectTimeout = connectTimeout {
    sourceAddress = _computeSourceAddress(_pointer.ref.fd);
    destinationAddress = _computeDestinationAddress();
  }

  Future<TransportOutboundPayload> read() async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(buffers.read(bufferId, length), () => buffers.release(bufferId)));
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(buffers.read(bufferId, length), () => buffers.release(bufferId)));
  }

  Future<void> sendMessage(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.sendMessage(
      bytes,
      bufferId,
      _pointer.ref.family,
      _bindings.transport_client_get_destination_address(_pointer),
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
    return completer.future;
  }

  Future<TransportOutboundPayload> readFlush() async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.readFlush(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(buffers.read(bufferId, length), () => buffers.release(bufferId)));
  }

  Future<void> writeFlush(Uint8List bytes) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.writeFlush(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessageFlush({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.receiveMessageFlush(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(buffers.read(bufferId, length), () => buffers.release(bufferId)));
  }

  Future<void> sendMessageFlush(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.sendMessageFlush(
      bytes,
      bufferId,
      _pointer.ref.family,
      _bindings.transport_client_get_destination_address(_pointer),
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
    return completer.future;
  }

  Future<TransportClient> connect() {
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<TransportClient>();
    _callbacks.setConnect(_pointer.ref.fd, completer);
    _bindings.transport_worker_connect(_workerPointer, _pointer, _connectTimeout!);
    _pending++;
    return completer.future;
  }

  @pragma(preferInlinePragma)
  bool notifyConnect() {
    _pending--;
    if (_active) return true;
    if (_pending == 0) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool notifyData(int bufferId) {
    _pending--;
    if (_active) return true;
    buffers.release(bufferId);
    if (_pending == 0) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0;

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _bindings.transport_client_destroy(_pointer);
    _registry.removeClient(_pointer.ref.fd);
  }

  @pragma(preferInlinePragma)
  String _computeSourceAddress(int fd) {
    if (_pointer.ref.family == transport_socket_family.UNIX) return unknown;
    final address = _bindings.transport_socket_fd_to_address(fd, _pointer.ref.family);
    if (address == nullptr) return unknown;
    final addressString = address.cast<Utf8>().toDartString();
    malloc.free(address);
    return "$addressString:${_bindings.transport_socket_fd_to_port(fd)}";
  }

  @pragma(preferInlinePragma)
  String _computeDestinationAddress() {
    final destination = _bindings.transport_client_get_destination_address(_pointer);
    final address = _bindings.transport_address_to_string(destination, _pointer.ref.family);
    final addressString = address.cast<Utf8>().toDartString();
    malloc.free(address);
    if (_pointer.ref.family == transport_socket_family.UNIX) return addressString;
    return "$addressString:${destination.cast<sockaddr_in>().ref.sin_port}";
  }
}

class TransportClientStreamCommunicators {
  final List<TransportClientStreamCommunicator> _communicators;
  var _next = 0;

  TransportClientStreamCommunicators(this._communicators);

  TransportClientStreamCommunicator select() {
    final client = _communicators[_next];
    if (++_next == _communicators.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportClientStreamCommunicator communicator) action) => _communicators.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportClientStreamCommunicator communicator) mapper) => _communicators.map(mapper);
}
