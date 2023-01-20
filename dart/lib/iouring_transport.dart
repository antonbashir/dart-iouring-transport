library iouring_transport;

import 'package:iouring_transport/transport/defaults.dart';

import 'transport/transport.dart';

void main(List<String> args) {
  final transport = Transport();
  transport.initialize(TransportDefaults.configuration());
  print(transport.initialized());
}
