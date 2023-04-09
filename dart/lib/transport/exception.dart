import 'package:iouring_transport/transport/extensions.dart';

class TransportException implements Exception {
  final String message;
  TransportException(this.message);
  factory TransportException.forEvent(int event, int code, String message, int fd, {int? bufferId}) => TransportException(
        "${event.transportEventToString()} code = $code, message = $message, fd = $fd" + (bufferId == null ? "" : ", bufferId = $bufferId"),
      );

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;
  TransportClosedException(this.message);
  factory TransportClosedException.forServer() => TransportClosedException("Server closed");
  factory TransportClosedException.forClient() => TransportClosedException("Client closed");
  factory TransportClosedException.forFile() => TransportClosedException("File closed");

  @override
  String toString() => message;
}
