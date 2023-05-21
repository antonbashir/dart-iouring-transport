import 'dart:async';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServerInternalConnection _connection;

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
