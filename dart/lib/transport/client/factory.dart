import 'dart:async';

import 'client.dart';
import 'communicator.dart';
import 'configuration.dart';
import 'registry.dart';

class TransportClientsFactory {
  final TransportClientRegistry _registry;

  TransportClientsFactory(this._registry);

  Future<TransportClientStreamCommunicators> tcp(
    String host,
    int port, {
    TransportTcpClientConfiguration? configuration,
  }) =>
      _registry.createTcp(host, port, configuration: configuration);

  TransportClientDatagramCommunicator udp(
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

  Future<TransportClientStreamCommunicators> unixStream(
    String path, {
    TransportUnixStreamClientConfiguration? configuration,
  }) =>
      _registry.createUnixStream(path, configuration: configuration);

  TransportClientDatagramCommunicator unixDatagram(
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
