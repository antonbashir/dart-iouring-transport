import 'dart:async';
import 'dart:ffi';
import 'dart:math';
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
  final TransportBuffers _buffers;
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
    this._buffers,
    this._registry, {
    int? connectTimeout,
  }) : _connectTimeout = connectTimeout {
    sourceAddress = _computeSourceAddress(_pointer.ref.fd);
    destinationAddress = _computeDestinationAddress();
  }

  Future<List<TransportOutboundPayload>> readChunks(int count) async {
    final chunks = <Future<TransportOutboundPayload>>[];
    final allocatedBuffers = <int>[];
    for (var index = 0; index < count; index++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    for (var index = 0; index < count - 1; index++) {
      final completer = Completer<int>();
      final bufferId = allocatedBuffers[index];
      _callbacks.setOutboundRead(bufferId, completer);
      _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
      _pending++;
      chunks.add(completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId))));
    }
    final completer = Completer<int>();
    final bufferId = allocatedBuffers[count - 1];
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.readFlush(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    chunks.add(completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId))));
    return Future.wait(chunks);
  }

  Future<TransportOutboundPayload> readFlush() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.readFlush(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId)));
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => bytes.length > _buffers.bufferSize ? _writeChunked(bytes) : _writeFlush(bytes);

  Future<void> writeFragments(Iterable<Uint8List> fragments) async {
    final chunks = <int, Uint8List>{};
    for (var fragment in fragments) chunks[_buffers.get() ?? await _buffers.allocate()] = fragment;
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final entries = chunks.entries.toList();
    final last = chunks.entries.length - 1;
    for (var index = 0; index < last; index++) {
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(entries[index].key, completer);
      _channel.write(entries[index].value, entries[index].key, _writeTimeout, transportEventWrite | transportEventClient);
      _pending++;
    }
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(entries[last].key, completer);
    _channel.writeFlush(entries[last].value, entries[last].key, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<void> _writeFlush(Uint8List bytes) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.writeFlush(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<void> _writeChunked(Uint8List bytes) async {
    final chunks = <int, Uint8List>{};
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks[_buffers.get() ?? await _buffers.allocate()] = bytes;
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final entries = chunks.entries.toList();
    final last = chunks.entries.length - 1;
    for (var index = 0; index < last; index++) {
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(entries[index].key, completer);
      _channel.write(entries[index].value, entries[index].key, _writeTimeout, transportEventWrite | transportEventClient);
      _pending++;
    }
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(entries[last].key, completer);
    _channel.writeFlush(entries[last].value, entries[last].key, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<List<TransportOutboundPayload>> receiveMessageChunks(int count, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <Future<TransportOutboundPayload>>[];
    final allocatedBuffers = <int>[];
    for (var index = 0; index < count; index++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    for (var index = 0; index < count - 1; index++) {
      final completer = Completer<int>();
      final bufferId = allocatedBuffers[index];
      _callbacks.setOutboundRead(bufferId, completer);
      _channel.receiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
      _pending++;
      chunks.add(completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId))));
    }
    final completer = Completer<int>();
    final bufferId = allocatedBuffers[count - 1];
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.receiveMessageFlush(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    chunks.add(completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId))));
    return Future.wait(chunks);
  }

  Future<TransportOutboundPayload> receiveMessageFlush({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.receiveMessageFlush(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId)));
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => bytes.length > _buffers.bufferSize ? _sendMessageChunks(bytes, flags: flags) : _sendMessageFlush(bytes, flags: flags);

  Future<void> _sendMessageChunks(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <int, Uint8List>{};
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks[_buffers.get() ?? await _buffers.allocate()] = bytes;
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forClient(sourceAddress, destinationAddress);
    final entries = chunks.entries.toList();
    final last = chunks.entries.length - 1;
    for (var index = 0; index < last; index++) {
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(entries[index].key, completer);
      _channel.sendMessage(
        entries[index].value,
        entries[index].key,
        _pointer.ref.family,
        _bindings.transport_client_get_destination_address(_pointer),
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventClient,
      );
      _pending++;
    }
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(entries[last].key, completer);
    _channel.sendMessageFlush(
      entries[last].value,
      entries[last].key,
      _pointer.ref.family,
      _bindings.transport_client_get_destination_address(_pointer),
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
    return completer.future;
  }

  Future<void> _sendMessageFlush(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
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
    _buffers.release(bufferId);
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
