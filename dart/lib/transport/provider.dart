import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';

class TransportProvider {
  final TransportConnector Function() _connectorFactory;
  final TransportFile Function(String path) _fileFactory;

  TransportProvider(this._connectorFactory, this._fileFactory);

  TransportFile file(String path) => _fileFactory(path);

  TransportConnector connector() => _connectorFactory();
}
