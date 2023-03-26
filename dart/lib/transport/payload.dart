import 'dart:typed_data';

import 'package:iouring_transport/transport/constants.dart';

class TransportOutboundPayload {
  final Uint8List bytes;
  final void Function() _releaser;

  TransportOutboundPayload(this.bytes, this._releaser);

  @pragma(preferInlinePragma)
  void release() => _releaser();
}

class TransportInboundPayload {
  final Uint8List bytes;
  final void Function(Uint8List? answer) _responder;

  TransportInboundPayload(this.bytes, this._responder);

  @pragma(preferInlinePragma)
  void release() => _responder(null);

  @pragma(preferInlinePragma)
  void respond(Uint8List answer) => _responder(answer);
}
