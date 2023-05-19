import 'constants.dart';

class TransportInitializationException implements Exception {
  final String message;

  TransportInitializationException(this.message);

  @override
  String toString() => message;
}

abstract class TransportExecutionException implements Exception {
  final int? bufferId;

  TransportExecutionException(this.bufferId);
}

class TransportInternalException extends TransportExecutionException {
  final TransportEvent event;
  final int code;

  late final String message;

  TransportInternalException({
    required this.event,
    required this.code,
    required String message,
    int? bufferId,
  }) : super(bufferId) {
    this.message = "[$event] code = $code, message = $message";
  }

  @override
  String toString() => message;
}

class TransportCanceledException extends TransportExecutionException {
  late final String message;
  final TransportEvent event;

  TransportCanceledException({required this.event, int? bufferId}) : super(bufferId) {
    this.message = "[$event] canceled";
  }

  @override
  String toString() => message;
}

class TransportClosedException extends TransportExecutionException {
  final String message;

  TransportClosedException._(this.message, {int? bufferId}) : super(bufferId);

  factory TransportClosedException.forServer({int? bufferId}) => TransportClosedException._("Server closed", bufferId: bufferId);

  factory TransportClosedException.forClient({int? bufferId}) => TransportClosedException._("Client closed", bufferId: bufferId);

  factory TransportClosedException.forFile({int? bufferId}) => TransportClosedException._("File closed", bufferId: bufferId);

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final TransportEvent event;

  late final String message;

  TransportZeroDataException({required this.event}) {
    message = "[$event] completed with zero result (no data)";
  }

  @override
  String toString() => message;
}
