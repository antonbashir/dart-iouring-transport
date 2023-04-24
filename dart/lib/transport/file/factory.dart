import 'communicator.dart';
import 'registry.dart';

class TransportFilesFactory {
  final TransportFileRegistry _registry;

  TransportFilesFactory(this._registry);

  TransportFileCommunicator open(String path) => TransportFileCommunicator(_registry.open(path));
}
