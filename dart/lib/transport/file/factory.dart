import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'file.dart';
import 'provider.dart';
import 'registry.dart';
import 'package:meta/meta.dart';

class TransportFilesFactory {
  final TransportFileRegistry _registry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;

  const TransportFilesFactory(
    this._registry,
    this._bindings,
    this._workerPointer,
    this._buffers,
    this._payloadPool,
  );

  TransportFile open(
    String path, {
    TransportFileMode mode = TransportFileMode.readWriteAppend,
    bool create = false,
    bool truncate = false,
  }) {
    final delegate = File(path);
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast(), mode.mode, truncate, create));
    if (fd < 0) throw TransportInitializationException(TransportMessages.fileOpenError(path));
    final file = TransportFileChannel(
      path,
      fd,
      _bindings,
      _workerPointer,
      TransportChannel(_workerPointer, fd, _bindings, _buffers),
      _buffers,
      _payloadPool,
      _registry,
    );
    _registry.add(fd, file);
    return TransportFile(file, delegate);
  }

  @visibleForTesting
  TransportFileRegistry get registry => _registry;
}
