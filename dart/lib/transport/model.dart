import 'constants.dart';

class TransportUri {
  final TransportSocketMode mode;
  final String? host;
  final int? port;
  final String? path;

  TransportUri(this.mode, {this.host, this.port, this.path});

  factory TransportUri.tcp(String host, int port) => TransportUri(TransportSocketMode.TCP, host: host, port: port);
}
