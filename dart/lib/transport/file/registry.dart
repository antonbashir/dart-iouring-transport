import 'dart:ffi';

import 'package:ffi/ffi.dart';
import '../exception.dart';
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

  final _files = <int, TransportFileChannel>{};

  TransportFileRegistry(this._bindings, this._workerPointer, this._buffers, this._payloadPool);

  @pragma(preferInlinePragma)
  TransportFileChannel? get(int fd) => _files[fd];

  TransportFileChannel open(String path, {TransportFileMode mode = TransportFileMode.readWriteAppend, bool create = false, bool truncate = false}) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast(), mode.mode, truncate, create));
    if (fd < 0) throw TransportInitializationException("[file] open file failed: $path");
    final file = TransportFileChannel(
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
  Map<int, TransportFileChannel> get files => _files;
}
