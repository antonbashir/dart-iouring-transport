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
        buffersCount: 1024,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: ringSetupSqpoll,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        maxConnections: 8192,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        defaultPool: 1,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 8192,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        ringSize: 2048,
        ringFlags: 0,
      );
}
