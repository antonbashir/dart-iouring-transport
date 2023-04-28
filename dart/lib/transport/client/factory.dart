import 'dart:async';
import 'dart:io';

import 'client.dart';
import 'provider.dart';
import 'configuration.dart';
import 'registry.dart';

class TransportClientsFactory {
  final TransportClientRegistry _registry;

  TransportClientsFactory(this._registry);

  Future<TransportClientStreamPool> tcp(
    InternetAddress address,
    int port, {
    TransportTcpClientConfiguration? configuration,
  }) =>
      _registry.createTcp(address.address, port, configuration: configuration);

  TransportClientDatagramProvider udp(
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
