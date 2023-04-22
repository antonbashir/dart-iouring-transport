import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../payload.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import 'file.dart';

class TransportFilesFactory {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;

  TransportFilesFactory(
    this._bindings,
    this._callbacks,
    this._workerPointer,
    this._buffers,
    this._payloadPool,
  );

  TransportFile open(String path) {
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFile(
      path,
      File(path),
      _callbacks,
      TransportChannel(_workerPointer, fd, _bindings, _buffers),
      _buffers,
      _payloadPool,
    );
  }
}
