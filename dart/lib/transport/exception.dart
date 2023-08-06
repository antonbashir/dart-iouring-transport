import 'payload.dart';
import 'bindings.dart';
import 'constants.dart';

class TransportInitializationException implements Exception {
  final String message;

  TransportInitializationException(this.message);

  @override
  String toString() => message;
}

class TransportInternalException implements Exception {
  final TransportEvent event;
  final int code;

  late final String message;

  TransportInternalException({
    required this.event,
    required this.code,
    required TransportBindings bindings,
  }) : this.message = TransportMessages.internalError(event, code, bindings);

  @override
  String toString() => message;
}

class TransportCanceledException implements Exception {
  final TransportEvent event;

  late final String message;

  TransportCanceledException(this.event) : this.message = TransportMessages.canceledError(event);

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  TransportClosedException._(this.message);

  factory TransportClosedException.forServer({TransportPayload? payload}) => TransportClosedException._(TransportMessages.serverClosedError);

  factory TransportClosedException.forClient({TransportPayload? payload}) => TransportClosedException._(TransportMessages.clientClosedError);

  factory TransportClosedException.forFile({TransportPayload? payload}) => TransportClosedException._(TransportMessages.fileClosedError);

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final TransportEvent event;

  late final String message;

  TransportZeroDataException(this.event) : message = TransportMessages.zeroDataError(event);

  @override
  String toString() => message;
}

@pragma(preferInlinePragma)
Exception createTransportException(TransportEvent event, int result, TransportBindings bindings) {
  if (result < 0) {
    if (result == -ECANCELED) {
      return TransportCanceledException(event);
    }
    return TransportInternalException(
      event: event,
      code: result,
      bindings: bindings,
    );
  }
  return TransportZeroDataException(event);
}
