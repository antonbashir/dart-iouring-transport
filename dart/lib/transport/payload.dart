import 'dart:typed_data';

import 'channels/channel.dart';

class TransportDataPayload {
  final TransportChannel _channel;
  final int _bufferId;

  late int _fd;
  late Uint8List _bytes;
  late void Function(TransportDataPayload payload) _finalizer;

  set fd(int value) => _fd = value;
  set finalizer(void Function(TransportDataPayload payload) value) => _finalizer = value;

  set bytes(Uint8List value) => _bytes = value;
  Uint8List get bytes => _bytes;

  TransportDataPayload(this._channel, this._bufferId);

  void respond(Uint8List data) {
    _finalizer(this);
    _channel.write(data, _fd, _bufferId);
  }

  void finalize() => _finalizer(this);
}
