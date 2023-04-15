import 'extensions.dart';

class TransportException implements Exception {
  final String message;

  TransportException(this.message);

  factory TransportException.forEvent(int event, int code, String message, int fd, {int? bufferId}) => TransportException(
        "${event.transportEventToString()} code = $code, message = $message, fd = $fd" + (bufferId == null ? "" : ", bufferId = $bufferId"),
      );

  @override
  String toString() => message;
}

class TransportCancelledException implements Exception {
  final String message;

  TransportCancelledException({this.message = "Event canceled"});

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
