import 'dart:io';

import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.debug,
        inboundIsolates: Platform.numberOfProcessors,
        outboundIsolates: Platform.numberOfProcessors,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 8192,
        bufferSize: 4096,
        ringSize: 16536,
        ringFlags: ringSetupSqpoll,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        maxConnections: 8192,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
        defaultPool: Platform.numberOfProcessors * 2,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 8192,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
        ringSize: 2048,
        ringFlags: 0,
      );
}
