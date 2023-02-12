import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/bindings.dart';
import 'package:iouring_transport/transport/channels/channel.dart';

class TransportDataPayload {
  final Pointer<transport_payload> _payload;
  final Uint8List bytes;
  final TransportChannel channel;
  final int fd;

  TransportDataPayload(this._payload, this.bytes, this.channel, this.fd);

  void finalize() {
    malloc.free(_payload.ref.data);
    malloc.free(_payload);
  }
}
