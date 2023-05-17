import 'dart:async';
import 'dart:typed_data';

import '../channel.dart';
import '../configuration.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServer _server;
  final TransportChannel _channel;

  const TransportServerConnection(this._server, this._channel);

  bool get active => !_server.closing;

  @pragma(preferInlinePragma)
  Future<TransportPayload> read({bool submit = true}) => _server.read(_channel, submit: submit);

  void listen(FutureOr<void> Function(TransportPayload payload, void Function() canceler) listener, {void Function(dynamic error)? onError}) async {
    var canceled = false;
    while (!_server.closing && _server.connectionIsActive(_channel.fd) && !canceled) {
      await read().then((value) => listener(value, () => canceled = true), onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {TransportRetryConfiguration? retry, bool submit = true}) => retry == null
      ? _server.writeSingle(_channel, bytes, submit: submit)
      : retry.options.retry(
          () => _server.writeSingle(_channel, bytes, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {TransportRetryConfiguration? retry, bool submit = true}) => retry == null
      ? _server.writeMany(_channel, bytes, submit: submit)
      : retry.options.retry(
          () => _server.writeMany(_channel, bytes, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.closeConnection(_channel.fd, gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
