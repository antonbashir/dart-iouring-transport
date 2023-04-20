import 'dart:typed_data';

import 'communicator.dart';

class TransportOutboundPayload {
  final Uint8List bytes;
  final void Function() _releaser;

  TransportOutboundPayload(this.bytes, this._releaser);

  void release() => _releaser();

  Uint8List extract({bool release = true}) {
    final result = Uint8List.fromList(bytes.toList());
    if (release) _releaser();
    return result;
  }
}

class TransportInboundStreamPayload {
  final Uint8List bytes;
  final void Function() _releaser;

  TransportInboundStreamPayload(this.bytes, this._releaser);

  void release() => _releaser();

  Uint8List extract({bool release = true}) {
    final result = Uint8List.fromList(bytes.toList());
    if (release) _releaser();
    return result;
  }
}

class TransportInboundDatagramPayload {
  final Uint8List bytes;
  final void Function() _releaser;
  final TransportServerDatagramSender sender;

  TransportInboundDatagramPayload(this.bytes, this.sender, this._releaser);

  void release() => _releaser();

  List<int> extract({bool release = true}) {
    final result = bytes.toList();
    if (release) _releaser();
    return result;
  }
}
