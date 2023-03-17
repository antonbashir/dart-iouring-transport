import 'dart:io';
import 'dart:math';

import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.debug,
        inboundIsolates: max(Platform.numberOfProcessors ~/ 2, 1),
        outboundIsolates: max(Platform.numberOfProcessors ~/ 2, 1),
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: min(256 * max(Platform.numberOfProcessors ~/ 2, 1), 4096),
        bufferSize: 4096,
        ringSize: min(4096 * max(Platform.numberOfProcessors ~/ 2, 1), 32768),
        ringFlags: ringSetupSqpoll,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        maxConnections: min(512 * Platform.numberOfProcessors, 32768),
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        defaultPool: min(16 * max(Platform.numberOfProcessors ~/ 2, 1), 1024),
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: min(512 * Platform.numberOfProcessors, 32768),
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        ringSize: min(512 * Platform.numberOfProcessors, 32768),
        ringFlags: 0,
      );
}
