import 'dart:async';

import '../constants.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerDatagramReceiver {
  final TransportServerChannel _server;

  const TransportServerDatagramReceiver(this._server);

  bool get active => !_server.closing;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveBySingle() {
    unawaited(_server.receiveSingleMessage());
    return _server.inbound.map((event) {
      unawaited(_server.receiveSingleMessage());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveByMany(int count) {
    unawaited(_server.receiveManyMessages(count));
    return _server.inbound.map((event) {
      unawaited(_server.receiveManyMessages(count));
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
