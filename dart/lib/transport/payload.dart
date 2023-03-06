import 'dart:typed_data';

import 'channels/channel.dart';

class TransportDataPayload {
  final TransportChannel channel;
  final int bufferId;

  late Uint8List bytes;
  late int fd;
  late void Function(TransportDataPayload payload) finalizer;

  TransportDataPayload(this.channel, this.bufferId);

  void respond(Uint8List data) {
    finalizer(this);
    channel.write(bytes, fd, bufferId);
  }

  void finalize() => finalizer(this);
}
