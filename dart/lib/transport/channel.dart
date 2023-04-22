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

  TransportChannel(this._workerPointer, this.fd, this._bindings, this._buffers);

  @pragma(preferInlinePragma)
  void addRead(int bufferId, int timeout, int event, {int offset = 0}) {
    _bindings.transport_worker_add_read(_workerPointer, fd, bufferId, offset, timeout, event);
  }

  @pragma(preferInlinePragma)
  void addWrite(Uint8List bytes, int bufferId, int timeout, int event, {int offset = 0}) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_add_write(_workerPointer, fd, bufferId, offset, timeout, event);
  }

  @pragma(preferInlinePragma)
  void addReceiveMessage(int bufferId, int socketFamily, int timeout, int flags, int event) {
    _bindings.transport_worker_add_receive_message(
      _workerPointer,
      fd,
      bufferId,
      socketFamily,
      flags,
      timeout,
      event,
    );
  }

  @pragma(preferInlinePragma)
  void addSendMessage(Uint8List bytes, int bufferId, int socketFamily, Pointer<sockaddr> destination, int timeout, int flags, int event) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_add_send_message(
      _workerPointer,
      fd,
      bufferId,
      destination,
      socketFamily,
      flags,
      timeout,
      event,
    );
  }

  @pragma(preferInlinePragma)
  void readSubmit(int bufferId, int timeout, int event, {int offset = 0}) {
    _bindings.transport_worker_read_submit(_workerPointer, fd, bufferId, offset, timeout, event);
  }

  @pragma(preferInlinePragma)
  void writeSubmit(Uint8List bytes, int bufferId, int timeout, int event, {int offset = 0}) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_write_submit(_workerPointer, fd, bufferId, offset, timeout, event);
  }

  @pragma(preferInlinePragma)
  void receiveMessageSubmit(int bufferId, int socketFamily, int timeout, int flags, int event) {
    _bindings.transport_worker_receive_message_submit(
      _workerPointer,
      fd,
      bufferId,
      socketFamily,
      flags,
      timeout,
      event,
    );
  }

  @pragma(preferInlinePragma)
  void sendMessageSubmit(Uint8List bytes, int bufferId, int socketFamily, Pointer<sockaddr> destination, int timeout, int flags, int event) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_send_message_submit(
      _workerPointer,
      fd,
      bufferId,
      destination,
      socketFamily,
      flags,
      timeout,
      event,
    );
  }

  @pragma(preferInlinePragma)
  void close() => _bindings.transport_close_descritor(fd);
}
