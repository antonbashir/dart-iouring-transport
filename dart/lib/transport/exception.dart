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
  final String source;
  final String target;

  late final String message;

  TransportInternalException({
    required this.event,
    required this.code,
    required String message,
    required this.source,
    required this.target,
  }) {
    this.message = "[$event] code = $code, message = $message, source = '$source', target = '$target'";
  }

  @override
  String toString() => message;
}

class TransportCancelledException implements Exception {
  late final String message;
  final TransportEvent event;
  final String source;
  final String target;

  TransportCancelledException({required this.event, required this.source, required this.target}) {
    this.message = "[$event] cancelled, source = '$source', target = '$target'";
  }

  @override
  String toString() => message;
}

class TransportClosedException implements Exception {
  final String message;

  TransportClosedException._(this.message);

  factory TransportClosedException.forServer(String server) => TransportClosedException._("Server closed: $server");

  factory TransportClosedException.forConnection(String server, String connection) => TransportClosedException._("Server connection closed: server = $server, connection = $connection");

  factory TransportClosedException.forClient(String client, String server) => TransportClosedException._("Client closed: client = $client, server = $server");

  @override
  String toString() => message;
}

class TransportZeroDataException implements Exception {
  final TransportEvent event;
  final String source;
  final String target;

  late final String message;

  TransportZeroDataException({
    required this.event,
    required this.source,
    required this.target,
  }) {
    message = "[$event] completed with zero result (no data), source = $source, target = $target";
  }

  @override
  String toString() => message;
}
