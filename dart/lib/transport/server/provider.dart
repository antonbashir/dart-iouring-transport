import 'dart:async';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServerConnectionChannel _connection;

  const TransportServerConnection(this._connection);

  bool get active => !_connection.closing;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> read() {
    unawaited(_connection.read());
    return _connection.inbound.map((event) {
      unawaited(_connection.read());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes) => _connection.writeSingle(bytes);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes) => _connection.writeMany(bytes);

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _connection.close(gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _connection.closeServer(gracefulDuration: gracefulDuration);
}


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
