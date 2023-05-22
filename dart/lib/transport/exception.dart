import 'package:ffi/ffi.dart';
import 'payload.dart';
import 'bindings.dart';
import 'constants.dart';

String kernelErrorToString(int error, TransportBindings bindings) => bindings.strerror(-error).cast<Utf8>().toDartString();

class TransportInitializationException implements Exception {
  final String message;

  TransportInitializationException(this.message);

  @override
  String toString() => message;
}

class TransportInternalException implements Exception {
  final TransportEvent event;
  final int code;
  final TransportPayload? payload;

  late final String message;

  TransportInternalException({
    required this.event,
    required this.code,
    this.payload,
    required String message,
    int? bufferId,
  }) {
    this.message = "[$event] code = $code, message = $message";
  }

  @override
  String toString() => message;
}

class TransportCanceledException implements Exception {
  final TransportEvent event;
  final TransportPayload? payload;

  late final String message;

  TransportCanceledException({required this.event, this.payload}) {
    this.message = "[$event] canceled";
  }

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  TransportClosedException._(this.message);

  factory TransportClosedException.forServer({TransportPayload? payload}) => TransportClosedException._("Server closed");

  factory TransportClosedException.forClient({TransportPayload? payload}) => TransportClosedException._("Client closed");

  factory TransportClosedException.forFile({TransportPayload? payload}) => TransportClosedException._("File closed");

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final TransportEvent event;
  final TransportPayload payload;

  late final String message;

  TransportZeroDataException({required this.event, required this.payload}) {
    message = "[$event] completed with zero result (no data)";
  }

  @override
  String toString() => message;
}

@pragma(preferInlinePragma)
Exception createTransportException(TransportEvent event, int result, TransportBindings bindings, {TransportPayload? payload}) {
  if (result < 0) {
    if (result == -ECANCELED) {
      return TransportCanceledException(event: event, payload: payload);
    }
    return TransportInternalException(
      event: event,
      code: result,
      message: kernelErrorToString(result, bindings),
      payload: payload,
    );
  }
  return TransportZeroDataException(event: event, payload: payload!);
}
