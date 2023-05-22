import 'dart:typed_data';

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
  final Uint8List? bytes;

  late final String message;

  TransportInternalException({
    required this.event,
    required this.code,
    this.bytes,
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
  final Uint8List? bytes;

  late final String message;

  TransportCanceledException({required this.event, this.bytes}) {
    this.message = "[$event] canceled";
  }

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  TransportClosedException._(this.message);

  factory TransportClosedException.forServer({TransportPayload? payload}) => TransportClosedException._("Server closed\n${StackTrace.current}");

  factory TransportClosedException.forClient({TransportPayload? payload}) => TransportClosedException._("Client closed\n${StackTrace.current}");

  factory TransportClosedException.forFile({TransportPayload? payload}) => TransportClosedException._("File closed\n${StackTrace.current}");

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final TransportEvent event;
  final Uint8List payload;

  late final String message;

  TransportZeroDataException({required this.event, required this.payload}) {
    message = "[$event] completed with zero result (no data)";
  }

  @override
  String toString() => message;
}

@pragma(preferInlinePragma)
Exception createTransportException(TransportEvent event, int result, TransportBindings bindings, {Uint8List? bytes}) {
  if (result < 0) {
    if (result == -ECANCELED) {
      return TransportCanceledException(event: event, bytes: bytes);
    }
    return TransportInternalException(
      event: event,
      code: result,
      message: kernelErrorToString(result, bindings),
      bytes: bytes,
    );
  }
  return TransportZeroDataException(event: event, payload: bytes!);
}
