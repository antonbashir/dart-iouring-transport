import 'dart:typed_data';

import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerConnection(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportPayload> read({bool submit = true}) => _server.read(_channel, submit: submit);

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {bool submit = true}) => _server.writeSingle(_channel, bytes, submit: submit);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true}) => _server.writeMany(_channel, bytes, submit: submit);

  void listen(void Function(TransportPayload payload) listener, {void Function(dynamic error)? onError}) async {
    while (!_server.closing && _server.connectionIsActive(_channel.fd)) {
      await read().then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.closeConnection(_channel.fd, gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
