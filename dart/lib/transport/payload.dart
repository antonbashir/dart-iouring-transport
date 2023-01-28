import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';

class TransportDataPayload {
  final TransportBindings _bindings;
  final Pointer<transport_channel_t> _channel;
  final Pointer<transport_data_payload_t> _payload;
  final Uint8List bytes;

  TransportDataPayload(this._bindings, this._channel, this._payload, this.bytes);

  void finalize() => _bindings.transport_channel_free_data_payload(_channel, _payload);
}
