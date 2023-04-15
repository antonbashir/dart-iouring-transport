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
