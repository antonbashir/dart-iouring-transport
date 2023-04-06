import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/server.dart';

import 'bindings.dart';
import 'constants.dart';
import 'worker.dart';

class TransportChannel {
  final int _descriptor;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportWorker _worker;

  late final Queue<Completer<int>> _bufferFinalizers;
  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;

  TransportChannel(this._workerPointer, this._descriptor, this._bindings, this._bufferFinalizers, this._worker) {
    _usedBuffers = _workerPointer.ref.used_buffers;
    _buffers = _workerPointer.ref.buffers;
  }
}

class TransportInboundChannel extends TransportChannel {
  final TransportServer _server;

  TransportInboundChannel(
    super._workerPointer,
    super._descriptor,
    super._bindings,
    super._bufferFinalizers,
    super.worker,
    this._server,
  ) : super();

  Future<int> _allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      bufferId = await completer.future;
      if (_usedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    }
    return bufferId;
  }

  Future<void> read() async {
    final bufferId = await _allocate();
    _bindings.transport_worker_read(_workerPointer, _descriptor, bufferId, 0, transportEventRead);
  }

  Future<void> receiveMessage({int flags = 0}) async {
    final bufferId = await _allocate();
    _bindings.transport_worker_receive_message(
      _workerPointer,
      _descriptor,
      bufferId,
      _server.pointer.ref.family,
      flags | MSG_TRUNC,
      transportEventReceiveMessage,
    );
  }

  void close() => _server.close();
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(super.pointer, super.descriptor, super._bindings, super._bufferFinalizers, super.worker) : super();

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      bufferId = await completer.future;
      if (_usedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    }
    return bufferId;
  }

  void read(int bufferId, {int offset = 0}) {
    _bindings.transport_worker_read(_workerPointer, _descriptor, bufferId, offset, transportEventReadCallback);
  }

  void write(Uint8List bytes, int bufferId, {int offset = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_workerPointer, _descriptor, bufferId, offset, transportEventWriteCallback);
  }

  void receiveMessage(int bufferId, Pointer<transport_client_t> client, {int flags = 0}) {
    _bindings.transport_worker_receive_message(
      _workerPointer,
      _descriptor,
      bufferId,
      client.ref.family,
      flags | MSG_TRUNC,
      transportEventReceiveMessageCallback,
    );
  }

  void sendMessage(Uint8List bytes, int bufferId, Pointer<transport_client_t> client, {int flags = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_send_message(
      _workerPointer,
      _descriptor,
      bufferId,
      _bindings.transport_client_get_destination_address(client).cast(),
      client.ref.family,
      flags | MSG_TRUNC,
      transportEventSendMessageCallback,
    );
  }

  void close() => _bindings.transport_close_descritor(_descriptor);
}
