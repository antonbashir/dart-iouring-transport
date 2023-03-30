import 'constants.dart';

class TransportUri {
  final TransportSocketMode mode;
  final String? inetHost;
  final int? inetPort;
  final String? unixPath;

  TransportUri._(this.mode, {this.inetHost, this.inetPort, this.unixPath});

  factory TransportUri.tcp(String host, int port) => TransportUri._(TransportSocketMode.tcp, inetHost: host, inetPort: port);

  factory TransportUri.udp(String host, int port) => TransportUri._(TransportSocketMode.udp, inetHost: host, inetPort: port);

  factory TransportUri.unixStream(String path) => TransportUri._(TransportSocketMode.unixStream, unixPath: path);

  factory TransportUri.unixDgram(String path) => TransportUri._(TransportSocketMode.unixDgram, unixPath: path);
}
