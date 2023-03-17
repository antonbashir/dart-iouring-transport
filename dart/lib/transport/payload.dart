import 'dart:typed_data';

class TransportPayload {
  final Uint8List bytes;
  final void Function(Uint8List? answer, int offset) _responder;

  TransportPayload(this.bytes, this._responder);

  void release() {
    _responder(null, 0);
  }

  void respond(Uint8List answer, {int offset = 0}) {
    _responder(answer, offset);
  }
}
