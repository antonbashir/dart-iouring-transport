import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/bindings.dart';

class TransportDataPayload {
  final Pointer<transport_payload> _payload;
  final Uint8List bytes;

  TransportDataPayload(this._payload, this.bytes);

  void finalize() {
    malloc.free(_payload.ref.data);
    malloc.free(_payload);
  }
}
