import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';
import 'package:iouring_transport/transport/channels/channel.dart';

class TransportDataPayload {
  final TransportBindings _bindings;
  final Pointer<transport_channel_t> _channel;
  final Pointer<transport_payload> _payload;

  final Uint8List bytes;
  final TransportChannel channel;
  final int fd;

  TransportDataPayload(this._bindings, this._channel, this._payload, this.bytes, this.channel, this.fd);

  void finalize() {
    _bindings.transport_channel_free_payload(_channel, _payload);
  }
}
