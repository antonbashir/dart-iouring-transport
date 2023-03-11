import 'dart:typed_data';

class TransportPayload {
  final Uint8List bytes;
  final void Function() _releaser;

  TransportPayload(this.bytes, this._releaser);

  Uint8List release() {
    _releaser();
    return bytes;
  }
}
