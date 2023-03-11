import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';
import 'package:iouring_transport/transport/loop.dart';

import 'bindings.dart';

class TransportProvider {
  final TransportEventLoop _loop;
  final TransportBindings _bindings;

  TransportProvider(this._loop, this._bindings);

  TransportClient client() => TransportClient(_loop.pointer, _bindings);

  TransportFile file() => TransportFile(_loop.pointer, _bindings);
}
