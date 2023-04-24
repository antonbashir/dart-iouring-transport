import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'file.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../links.dart';
import '../payload.dart';

class TransportFileRegistry {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;

  final _files = <int, TransportFile>{};

  TransportFileRegistry(this._bindings, this._callbacks, this._workerPointer, this._buffers, this._payloadPool, this._links);

  TransportFile get(int fd) => _files[fd]!;

  TransportFile open(String path) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    final file = TransportFile(
      path,
      File(path),
      fd,
      _bindings,
      _workerPointer,
      _callbacks,
      TransportChannel(_workerPointer, fd, _bindings, _buffers),
      _buffers,
      _links,
      _payloadPool,
      this,
    );
    _files[fd] = file;
    return file;
  }

  Future<void> close({Duration? gracefulDuration}) => Future.wait(_files.values.map((file) => file.close(gracefulDuration: gracefulDuration)));

  void remove(int fd) => _files.remove(fd);
}
