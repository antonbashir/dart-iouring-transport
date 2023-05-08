import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerDatagramReceiver {
  final TransportServer _server;
  final TransportChannel _channel;

  const TransportServerDatagramReceiver(this._server, this._channel);

  bool get active => !_server.closing;

  @pragma(preferInlinePragma)
  Future<TransportDatagramResponder> receiveSingleMessage({
    bool submit = true,
    int? flags,
  }) =>
      _server.receiveSingleMessage(_channel, flags: flags, submit: submit);

  @pragma(preferInlinePragma)
  Future<List<TransportDatagramResponder>> receiveManyMessages(
    int count, {
    bool submit = true,
    int? flags,
  }) =>
      _server.receiveManyMessages(_channel, count, flags: flags, submit: submit);

  void listen(
    void Function(TransportDatagramResponder payload, void Function() canceler) listener, {
    void Function(dynamic error)? onError,
    int? flags,
  }) async {
    var canceled = false;
    while (!_server.closing && !canceled) {
      await receiveSingleMessage(flags: flags).then((value) => listener(value, () => canceled = true), onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
