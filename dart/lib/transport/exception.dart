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

class TransportTimeoutException implements Exception {
  final String message;
  TransportTimeoutException(this.message);
  factory TransportTimeoutException.forServer() => TransportTimeoutException("Server timeout error\n: ${StackTrace.current.toString()}");
  factory TransportTimeoutException.forClient() => TransportTimeoutException("Client timeout error\n: ${StackTrace.current.toString()}");
  factory TransportTimeoutException.forFile() => TransportTimeoutException("File timeout error\n: ${StackTrace.current.toString()}");

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;
  TransportClosedException(this.message);
  factory TransportClosedException.forServer() => TransportClosedException("Server closed\n: ${StackTrace.current.toString()}");
  factory TransportClosedException.forConnection() => TransportClosedException("Connection closed\n: ${StackTrace.current.toString()}");
  factory TransportClosedException.forClient() => TransportClosedException("Client closed\n: ${StackTrace.current.toString()}");
  factory TransportClosedException.forFile() => TransportClosedException("File closed\n: ${StackTrace.current.toString()}");

  @override
  String toString() => message;
}
