import 'registry.dart';
import 'file.dart';

class TransportFilesFactory {
  final TransportFileRegistry _registry;

  TransportFilesFactory(this._registry);

  TransportFile open(String path) => _registry.open(path);
}
