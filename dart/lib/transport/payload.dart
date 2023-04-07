import 'dart:typed_data';

import 'constants.dart';

class TransportOutboundPayload {
  final Uint8List bytes;
  final void Function() _releaser;

  TransportOutboundPayload(this.bytes, this._releaser);

  void release() => _releaser();

  List<int> extract({bool release = true}) {
    final result = bytes.toList();
    if (release) _releaser();
    return result;
  }
}

class TransportInboundPayload {
  final Uint8List bytes;
  final void Function(Uint8List answer) _responder;
  final void Function() _releaser;

  TransportInboundPayload(this.bytes, this._responder, this._releaser);

  void release() => _releaser();

  void respond(Uint8List answer) => _responder(answer);

  List<int> extract({bool release = true}) {
    final result = bytes.toList();
    if (release) _releaser();
    return result;
  }
}
