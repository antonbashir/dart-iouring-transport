import 'dart:async';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServerConnectionChannel _connection;

  const TransportServerConnection(this._connection);

  Stream<TransportPayload> get inbound => _connection.inbound;
  bool get active => !_connection.closing;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> read() {
    unawaited(_connection.read());
    return _connection.inbound.map((event) {
      if (_connection.active) unawaited(_connection.read());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  void writeSingle(
    Uint8List bytes, {
    void Function(Exception error)? onError,
  }) =>
      unawaited(_connection.writeSingle(bytes, onError: onError));

  @pragma(preferInlinePragma)
  void writeMany(
    List<Uint8List> bytes, {
    void Function(Exception error)? onError,
  }) =>
      unawaited(_connection.writeMany(bytes, onError: onError));

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _connection.close(gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _connection.closeServer(gracefulDuration: gracefulDuration);
}

class TransportServerDatagramReceiver {
  final TransportServerChannel _server;

  const TransportServerDatagramReceiver(this._server);

  Stream<TransportDatagramResponder> get inbound => _server.inbound;
  bool get active => _server.active;

  @pragma(preferInlinePragma)
  Stream<TransportDatagramResponder> receive() {
    unawaited(_server.receiveSingleMessage());
    return _server.inbound.map((event) {
      if (_server.active) unawaited(_server.receiveSingleMessage());
      return event;
    }).handleError((error) {
      if (_server.active) unawaited(_server.receiveSingleMessage());
      throw error;
    });
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
