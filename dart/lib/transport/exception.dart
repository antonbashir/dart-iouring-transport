import 'extensions.dart';

class TransportEventException implements Exception {
  final String message;

  TransportEventException(this.message);

  factory TransportEventException.forEvent(int event, int code, String message, int fd, {int? bufferId}) => TransportEventException(
        "${event.transportEventToString()} code = $code, message = $message, fd = $fd" + (bufferId == null ? "" : ", bufferId = $bufferId"),
      );

  @override
  String toString() => message;
}

class TransportCancelledException implements Exception {
  late final String message;

  TransportCancelledException() {
    message = "Event canceled\n${StackTrace.current.toString()}";
  }

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  TransportClosedException._(this.message);

  factory TransportClosedException.forServer() => TransportClosedException._("Server closed");
  factory TransportClosedException.forConnection() => TransportClosedException._("Server connection closed");
  factory TransportClosedException.forClient() => TransportClosedException._("Client closed");

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final String message;

  TransportZeroDataException._(this.message);

  factory TransportZeroDataException() => TransportZeroDataException._("Event completed with zero result (no data)");

  @override
  String toString() => message;
}
