import 'dart:typed_data';

import 'package:iouring_transport/transport/bindings.dart';
import 'package:iouring_transport/transport/channels/channel.dart';

class TransportDataPayload {
  final int _bufferId;
  final TransportBindings _bindings;
  final TransportChannel channel;

  late Uint8List bytes;
  late int fd;

  TransportDataPayload(this._bindings, this._bufferId, this.channel);

  void finalize() => _bindings.transport_channel_free_buffer(channel.channel, _bufferId);
}
