import 'dart:async';
import 'dart:io';

import 'client.dart';
import 'provider.dart';
import 'configuration.dart';
import 'registry.dart';

import 'package:meta/meta.dart';

class TransportClientsFactory {
  final TransportClientRegistry _registry;

  const TransportClientsFactory(this._registry);

  Future<TransportClientConnectionPool> tcp(
    InternetAddress address,
    int port, {
    TransportTcpClientConfiguration? configuration,
  }) =>
      _registry.createTcp(address.address, port, configuration: configuration);

  TransportDatagramClient udp(
    InternetAddress sourceAddress,
    int sourcePort,
    InternetAddress destinationAddress,
    int destinationPort, {
    TransportUdpClientConfiguration? configuration,
  }) =>
      _registry.createUdp(
        sourceAddress.address,
        sourcePort,
        destinationAddress.address,
        destinationPort,
        configuration: configuration,
      );

  Future<TransportClientConnectionPool> unixStream(
    String path, {
    TransportUnixStreamClientConfiguration? configuration,
  }) =>
      _registry.createUnixStream(path, configuration: configuration);

  TransportDatagramClient unixDatagram(
    String sourcePath,
    String destinationPath, {
    TransportUnixDatagramClientConfiguration? configuration,
  }) =>
      _registry.createUnixDatagram(
        sourcePath,
        destinationPath,
        configuration: configuration,
      );

  @visibleForTesting
  TransportClientRegistry get registry => _registry;
}
