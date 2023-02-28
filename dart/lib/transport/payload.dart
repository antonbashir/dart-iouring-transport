import 'dart:typed_data';

import 'package:iouring_transport/transport/channels/channel.dart';

class TransportDataPayload {
  final void Function(TransportDataPayload finalizable) _finalizer;

  final Uint8List bytes;
  final TransportChannel channel;
  final int fd;

  TransportDataPayload(this.bytes, this.channel, this.fd, this._finalizer);

  void finalize() => _finalizer(this);
}
