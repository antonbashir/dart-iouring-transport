import '../channels.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerDatagramReceiver {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramReceiver(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportDatagramResponder> receiveMessage({int? flags}) => _server.receiveMessage(_channel, flags: flags);

  void listen(
    void Function(TransportDatagramResponder payload) listener, {
    void Function(Exception error, StackTrace stackTrace)? onError,
    int? flags,
  }) async {
    while (!_server.closing) {
      await receiveMessage(flags: flags).then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error, stackTrace);
      });
    }
  }
}
