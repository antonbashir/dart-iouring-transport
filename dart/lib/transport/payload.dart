import 'dart:typed_data';

import 'communicator.dart';
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

class TransportInboundStreamPayload {
  final Uint8List bytes;
  final void Function() _releaser;
  final Future<void> Function(Uint8List bytes) _responder;

  TransportInboundStreamPayload(this.bytes, this._releaser, this._responder);

  void release() => _releaser();

  Future<void> respond(Uint8List bytes) => _responder(bytes);

  List<int> extract({bool release = true}) {
    final result = bytes.toList();
    if (release) _releaser();
    return result;
  }
}

class TransportInboundDatagramPayload {
  final Uint8List bytes;
  final void Function() _releaser;
  final Future<void> Function(Uint8List bytes, {int? flags}) _responder;
  final TransportServerDatagramSender sender;

  TransportInboundDatagramPayload(this.bytes, this.sender, this._releaser, this._responder);

  void release() => _releaser();

  Future<void> respond(Uint8List bytes, {int? flags}) => _responder(bytes);

  List<int> extract({bool release = true}) {
    final result = bytes.toList();
    if (release) _releaser();
    return result;
  }
}
