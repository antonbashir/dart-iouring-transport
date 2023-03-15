import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';

class TransportProvider {
  final TransportConnector connector;
  final TransportFile Function(String path) _fileFactory;

  TransportProvider(this.connector, this._fileFactory);

  TransportFile file(String path) => _fileFactory(path);
}
