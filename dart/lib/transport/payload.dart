import 'dart:typed_data';

class TransportPayload {
  final Uint8List bytes;
  final void Function(Uint8List answer) _responder;

  TransportPayload(this.bytes, this._responder);

  void respond(Uint8List answer) {
    _responder(answer);
  }
}
