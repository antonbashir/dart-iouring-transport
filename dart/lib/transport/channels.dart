import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';
import 'worker.dart';

class TransportChannel {
  final int _descriptor;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportWorker worker;
  late final Queue<Completer<int>> _bufferFinalizers;

  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;

  TransportChannel(this._workerPointer, this._descriptor, this._bindings, this._bufferFinalizers, this.worker) {
    _usedBuffers = _workerPointer.ref.used_buffers;
    _buffers = _workerPointer.ref.buffers;
  }

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

  void close() => _bindings.transport_close_descritor(_descriptor);
}

class TransportInboundChannel extends TransportChannel {
  final Pointer<transport_server_t> _serverPointer;

  TransportInboundChannel(super._workerPointer, super._descriptor, super._bindings, super._bufferFinalizers, super.worker, this._serverPointer) : super();

  Future<void> read() async {
    final bufferId = await allocate();
    final submitted = _bindings.transport_worker_read(_workerPointer, _descriptor, bufferId, 0, transportEventRead);
    //worker.logger.debug("[inbound send read]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted =  $submitted");
  }

  Future<void> receiveMessage({int flags = 0}) async {
    final bufferId = await allocate();
    if (_serverPointer.ref.mode == transport_socket_mode.UDP) {
      _bindings.transport_worker_receive_message_inet(
        _workerPointer,
        _descriptor,
        bufferId,
        _serverPointer.ref.server_address_length,
        flags | MSG_TRUNC,
        transportEventReceiveMessage,
      );
      return;
    }

    _bindings.transport_worker_receive_message_unix(
      _workerPointer,
      _descriptor,
      bufferId,
      _serverPointer.ref.server_address_length,
      flags | MSG_TRUNC,
      transportEventReceiveMessage,
    );
  }
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(super.pointer, super.descriptor, super._bindings, super._bufferFinalizers, super.worker) : super();

  void read(int bufferId, {int offset = 0}) {
    final submitted = _bindings.transport_worker_read(_workerPointer, _descriptor, bufferId, offset, transportEventReadCallback);
    //worker.logger.debug("[outbound send read]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted = $submitted");
  }

  void write(Uint8List bytes, int bufferId, {int offset = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    final submitted = _bindings.transport_worker_write(_workerPointer, _descriptor, bufferId, offset, transportEventWriteCallback);
    //worker.logger.debug("[outbound send write]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted = $submitted");
  }

  void receiveMessage(int bufferId, Pointer<transport_client_t> client, {int flags = 0}) {
    if (client.ref.mode == transport_socket_mode.UDP) {
      _bindings.transport_worker_receive_message_inet(
        _workerPointer,
        _descriptor,
        bufferId,
        client.ref.client_address_length,
        flags | MSG_TRUNC,
        transportEventReceiveMessageCallback,
      );
      return;
    }
    _bindings.transport_worker_receive_message_unix(
      _workerPointer,
      _descriptor,
      bufferId,
      client.ref.client_address_length,
      flags | MSG_TRUNC,
      transportEventReceiveMessageCallback,
    );
  }

  void sendMessage(Uint8List bytes, int bufferId, Pointer<transport_client_t> client, {int flags = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    if (client.ref.mode == transport_socket_mode.UDP) {
      _bindings.transport_worker_send_message_inet(
        _workerPointer,
        _descriptor,
        bufferId,
        _bindings.transport_client_get_destination_address(client).cast(),
        client.ref.client_address_length,
        flags | MSG_TRUNC,
        transportEventSendMessageCallback,
      );
      return;
    }
    _bindings.transport_worker_send_message_unix(
      _workerPointer,
      _descriptor,
      bufferId,
      _bindings.transport_client_get_destination_address(client).cast(),
      client.ref.client_address_length,
      flags | MSG_TRUNC,
      transportEventSendMessageCallback,
    );
  }
}
