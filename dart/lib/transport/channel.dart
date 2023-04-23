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
  void addRead(int bufferId, int timeout, int event, int sqeFlags, {int sequenceId = 0, int offset = 0}) {
    _bindings.transport_worker_add_read(
      _workerPointer,
      fd,
      bufferId,
      offset,
      timeout,
      event,
      sqeFlags,
      sequenceId,
    );
  }

  @pragma(preferInlinePragma)
  void addWrite(Uint8List bytes, int bufferId, int timeout, int event, int sqeFlags, {int offset = 0}) {
    _buffers.write(bufferId, bytes);
    _bindings.transport_worker_add_write(
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
  void addReceiveMessage(int bufferId, int socketFamily, int timeout, int flags, int event, int sqeFlags) {
    _bindings.transport_worker_add_receive_message(
      _workerPointer,
      fd,
      bufferId,
      socketFamily,
      flags,
      timeout,
      event,
      sqeFlags,
    );
  }

  @pragma(preferInlinePragma)
  void addSendMessage(Uint8List bytes, int bufferId, int socketFamily, Pointer<sockaddr> destination, int timeout, int flags, int event, int sqeFlags) {
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
      sqeFlags,
      0,
    );
  }

  @pragma(preferInlinePragma)
  void close() => _bindings.transport_close_descritor(fd);
}
