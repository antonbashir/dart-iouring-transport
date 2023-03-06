import 'dart:typed_data';

import 'channel.dart';

class TransportDataPayload {
  final TransportChannel _channel;
  final int _bufferId;

  late int fd;
  late void Function(TransportDataPayload payload) finalizer;
  late Uint8List bytes;

  TransportDataPayload(this._channel, this._bufferId);

  void respond(Uint8List data) {
    finalizer(this);
    _channel.write(data, fd, _bufferId);
  }

  void finalize() => finalizer(this);
}
