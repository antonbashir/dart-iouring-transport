import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';

class TransportPayload implements Finalizable {
  final TransportBindings _bindings;
  final Pointer<transport_payload_t> _payload;
  final Uint8List bytes;

  TransportPayload(this._bindings, this._payload, this.bytes);

  void finalize() => _bindings.transport_finalize_payload(_payload);
}
