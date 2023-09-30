import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'buffers.dart';
import 'constants.dart';

class TransportChannel {
  final int fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportBuffers _buffers;

  const TransportChannel(this._workerPointer, this.fd, this._bindings, this._buffers);

  @pragma(preferInlinePragma)
  void read(
    int bufferId,
    int timeout,
    int event, {
    int sqeFlags = 0,
    int offset = 0,
  }) {
    _bindings.transport_worker_read(
      _workerPointer,
      fd,
      bufferId,
      offset,
      timeout,
      event,
      sqeFlags,
    );
  }

  @pragma(preferInlinePragma)
  void write(
    Uint8List bytes,
    int bufferId,
    int timeout,
    int event, {
    int sqeFlags = 0,
    int offset = 0,
  }) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_write(
      _workerPointer,
      fd,
      bufferId,
      offset,
      timeout,
      event,
      sqeFlags,
    );
  }

  @pragma(preferInlinePragma)
  void receiveMessage(
    int bufferId,
    int socketFamily,
    int timeout,
    int messageFlags,
    int event, {
    int sqeFlags = 0,
  }) {
    _bindings.transport_worker_receive_message(
      _workerPointer,
      fd,
      bufferId,
      socketFamily,
      messageFlags,
      timeout,
      event,
      sqeFlags,
    );
  }

  @pragma(preferInlinePragma)
  void sendMessage(
    Uint8List bytes,
    int bufferId,
    int socketFamily,
    Pointer<sockaddr> destination,
    int timeout,
    int messageFlags,
    int event, {
    int sqeFlags = 0,
  }) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_send_message(
      _workerPointer,
      fd,
      bufferId,
      destination,
      socketFamily,
      messageFlags,
      timeout,
      event,
      sqeFlags,
    );
  }

  @pragma(preferInlinePragma)
  void close() => _bindings.transport_close_descriptor(fd);
}
