import 'provider.dart';
import 'registry.dart';

class TransportFilesFactory {
  final TransportFileRegistry _registry;

  TransportFilesFactory(this._registry);

  TransportFileProvider open(String path) => TransportFileProvider(_registry.open(path));
}
