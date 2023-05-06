import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:meta/meta.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../links.dart';
import '../payload.dart';
import 'file.dart';

const _optionRdonly = 0;
const _optionWronly = 1;
const _optionRdwr = 2;
const _optionCreat = 100;
const _optionTrunc = 1000;
const _optionAppend = 2000;

class TransportFileRegistry {
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBuffers _buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;

  final _files = <int, TransportFile>{};

  TransportFileRegistry(this._bindings, this._callbacks, this._workerPointer, this._buffers, this._payloadPool, this._links);

  @pragma(preferInlinePragma)
  TransportFile? get(int fd) => _files[fd];

  TransportFile open(String path, {TransportFileMode mode = TransportFileMode.readWriteAppend, bool create = false, bool truncate = false, int permissions = 0644}) {
    var options = 0;
    switch (mode) {
      case TransportFileMode.readOnly:
        options = _optionRdonly;
        break;
      case TransportFileMode.writeOnly:
        options = _optionWronly;
        break;
      case TransportFileMode.readWrite:
        options = _optionRdwr;
        break;
      case TransportFileMode.writeOnlyAppend:
        options = _optionWronly | _optionAppend;
        break;
      case TransportFileMode.readWriteAppend:
        options = _optionRdwr | _optionAppend;
        break;
    }
    if (truncate) options |= _optionTrunc;
    if (create) options |= _optionCreat;
    final fd = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast(), options, permissions));
    if (fd < 0) throw TransportInitializationException("[file] open file failed: $path");
    final file = TransportFile(
      path,
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

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_files.values.toList().map((file) => file.close(gracefulDuration: gracefulDuration)));

  @pragma(preferInlinePragma)
  void remove(int fd) => _files.remove(fd);

  @visibleForTesting
  Map<int, TransportFile> get files => _files;
}
