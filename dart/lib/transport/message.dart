import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';

class TransportMessage implements Finalizable {
  final TransportBindings _bindings;
  final Pointer<transport_data_t> _data;
  final Uint8List bytes;

  late final NativeFinalizer _finalizer;

  TransportMessage(this._bindings, this._data, this.bytes) {
    _finalizer = NativeFinalizer(_bindings.addresses.transport_free_data.cast());
    _finalizer.attach(this, _data.cast(), detach: this);
  }
}
