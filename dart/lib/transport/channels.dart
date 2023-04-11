import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/client.dart';

import 'bindings.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';

class TransportChannel {
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;

  late final Queue<Completer<int>> _bufferFinalizers;
  late final Pointer<iovec> _buffers;

  TransportChannel(this._workerPointer, this._fd, this._bindings, this._bufferFinalizers) {
    _buffers = _workerPointer.ref.buffers;
  }
}

class TransportInboundChannel extends TransportChannel {
  final TransportServer _server;

  TransportInboundChannel(
    super._workerPointer,
    super._fd,
    super._bindings,
    super._bufferFinalizers,
    this._server,
  ) : super();

  Future<int> _allocate() async {
    var bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    while (bufferId == transportBufferUsed) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    }
    return bufferId;
  }

  Future<void> read() async {
    final bufferId = await _allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    _bindings.transport_worker_read(_workerPointer, _fd, bufferId, 0, _server.readTimeout, transportEventRead);
  }

  Future<void> receiveMessage() async {
    final bufferId = await _allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    _bindings.transport_worker_receive_message(
      _workerPointer,
      _fd,
      bufferId,
      _server.pointer.ref.family,
      _server.messageFlags,
      _server.readTimeout,
      transportEventReceiveMessage,
    );
  }

  Future<void> close() => _server.close();
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(
    super._workerPointer,
    super._fd,
    super._bindings,
    super._bufferFinalizers,
  ) : super();

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    while (bufferId == transportBufferUsed) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    }
    return bufferId;
  }

  @pragma(preferInlinePragma)
  void read(int bufferId, int timeout, {int offset = 0}) {
    _bindings.transport_worker_read(_workerPointer, _fd, bufferId, offset, timeout, transportEventRead | transportEventClient);
  }

  @pragma(preferInlinePragma)
  void write(Uint8List bytes, int bufferId, int timeout, {int offset = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_workerPointer, _fd, bufferId, offset, timeout, transportEventWrite | transportEventClient);
  }

  @pragma(preferInlinePragma)
  void receiveMessage(int bufferId, TransportClient client, int timeout) {
    _bindings.transport_worker_receive_message(
      _workerPointer,
      _fd,
      bufferId,
      client.pointer.ref.family,
      client.messageFlags!,
      timeout,
      transportEventReceiveMessage | transportEventClient,
    );
  }

  @pragma(preferInlinePragma)
  void sendMessage(Uint8List bytes, int bufferId, TransportClient client, int timeout) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_send_message(
      _workerPointer,
      _fd,
      bufferId,
      _bindings.transport_client_get_destination_address(client.pointer).cast(),
      client.pointer.ref.family,
      client.messageFlags!,
      timeout,
      transportEventSendMessage | transportEventClient,
    );
  }

  @pragma(preferInlinePragma)
  void close() => _bindings.transport_close_descritor(_fd);
}
