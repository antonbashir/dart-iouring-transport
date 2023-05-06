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

  TransportInternalException({required this.event, required this.code, required String message}) {
    this.message = "[$event] code = $code, message = $message";
  }

  @override
  String toString() => message;
}

class TransportCancelledException implements Exception {
  late final String message;
  final TransportEvent event;

  TransportCancelledException({required this.event}) {
    this.message = "[$event] cancelled";
  }

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  const TransportClosedException._(this.message);

  factory TransportClosedException.forServer() => TransportClosedException._("Server closed");

  factory TransportClosedException.forClient() => TransportClosedException._("Client closed");

  factory TransportClosedException.forFile() => TransportClosedException._("File closed");

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
