import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';

class TransportPayload implements Finalizable {
  final TransportBindings _bindings;
  final Pointer<transport_payload_t> _data;
  final Uint8List bytes;

  late final NativeFinalizer _finalizer;

  TransportPayload(this._bindings, this._data, this.bytes) {
    _finalizer = NativeFinalizer(_bindings.addresses.transport_finalize_payload.cast());
    _finalizer.attach(this, _data.cast(), detach: this);
  }
}
