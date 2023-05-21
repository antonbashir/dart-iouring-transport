import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:meta/meta.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../payload.dart';
import 'file.dart';

class TransportFileRegistry {
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;

  final _files = <int, TransportFile>{};

  TransportFileRegistry(this._bindings, this._workerPointer, this._buffers, this._payloadPool);

  @pragma(preferInlinePragma)
  TransportFile? get(int fd) => _files[fd];

  TransportFile open(String path, {TransportFileMode mode = TransportFileMode.readWriteAppend, bool create = false, bool truncate = false}) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast(), mode.mode, truncate, create));
    if (fd < 0) throw TransportInitializationException("[file] open file failed: $path");
    final file = TransportFile(
      path,
      fd,
      _bindings,
      _workerPointer,
      TransportChannel(_workerPointer, fd, _bindings, _buffers),
      _buffers,
      _payloadPool,
      this,
    );
    _files[fd] = file;
    return file;
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_files.values.toList().map((file) => file.close(gracefulDuration: gracefulDuration)));

  @pragma(preferInlinePragma)
  void remove(int fd) => _files.remove(fd);

  @visibleForTesting
  Map<int, TransportFile> get files => _files;
}
