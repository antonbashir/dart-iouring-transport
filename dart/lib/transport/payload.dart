import 'dart:typed_data';

import 'channels/channel.dart';

class TransportDataPayload {
  final TransportChannel channel;

  late Uint8List bytes;
  late int fd;
  late void Function(TransportDataPayload payload) finalizer;

  TransportDataPayload(this.channel);

  void finalize() => finalizer(this);
}
