import 'dart:io';

import 'package:meta/meta.dart';

import 'configuration.dart';
import 'provider.dart';
import 'registry.dart';
import 'server.dart';

class TransportServersFactory {
  final TransportServerRegistry _registry;

  const TransportServersFactory(this._registry);

  TransportServer tcp(
    InternetAddress address,
    int port,
    void Function(TransportServerConnection connection) onAccept, {
    TransportTcpServerConfiguration? configuration,
  }) =>
      _registry.createTcp(address.address, port, configuration: configuration)..accept(onAccept);

  TransportServerDatagramReceiver udp(
    InternetAddress address,
    int port, {
    TransportUdpServerConfiguration? configuration,
  }) {
    final server = _registry.createUdp(address.address, port, configuration: configuration);
    return TransportServerDatagramReceiver(server);
  }

  TransportServer unixStream(
    String path,
    void Function(TransportServerConnection connection) onAccept, {
    TransportUnixStreamServerConfiguration? configuration,
  }) =>
      _registry.createUnixStream(path, configuration: configuration)..accept(onAccept);

  TransportServerDatagramReceiver unixDatagram(String path, {TransportUnixDatagramServerConfiguration? configuration}) {
    final server = _registry.createUnixDatagram(path, configuration: configuration);
    return TransportServerDatagramReceiver(server);
  }

  @visibleForTesting
  TransportServerRegistry get registry => _registry;
}
