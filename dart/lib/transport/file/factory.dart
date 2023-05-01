import 'dart:io';

import 'provider.dart';
import 'registry.dart';
import 'package:meta/meta.dart';

class TransportFilesFactory {
  final TransportFileRegistry _registry;

  @visibleForTesting
  TransportFileRegistry get registry => _registry;

  TransportFilesFactory(this._registry);

  TransportFileProvider open(String path) => TransportFileProvider(_registry.open(path), File(path));
}
