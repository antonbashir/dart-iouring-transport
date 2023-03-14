import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';

class TransportProvider {
  final TransportConnector connector;
  final TransportFile Function(String path) fileFactory;

  TransportProvider(this.connector, this.fileFactory);

  file(String path) => fileFactory(path);
}
