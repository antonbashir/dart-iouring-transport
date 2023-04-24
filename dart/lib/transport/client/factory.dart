import 'dart:async';

import 'client.dart';
import 'provider.dart';
import 'configuration.dart';
import 'registry.dart';

class TransportClientsFactory {
  final TransportClientRegistry _registry;

  TransportClientsFactory(this._registry);

  Future<TransportClientStreamPool> tcp(
    String host,
    int port, {
    TransportTcpClientConfiguration? configuration,
  }) =>
      _registry.createTcp(host, port, configuration: configuration);

  TransportClientDatagramProvider udp(
    String sourceHost,
    int sourcePort,
    String destinationHost,
    int destinationPort, {
    TransportUdpClientConfiguration? configuration,
  }) =>
      _registry.createUdp(
        sourceHost,
        sourcePort,
        destinationHost,
        destinationPort,
        configuration: configuration,
      );

  Future<TransportClientStreamPool> unixStream(
    String path, {
    TransportUnixStreamClientConfiguration? configuration,
  }) =>
      _registry.createUnixStream(path, configuration: configuration);

  TransportClientDatagramProvider unixDatagram(
    String sourcePath,
    String destinationPath, {
    TransportUnixDatagramClientConfiguration? configuration,
  }) =>
      _registry.createUnixDatagram(
        sourcePath,
        destinationPath,
        configuration: configuration,
      );
}
