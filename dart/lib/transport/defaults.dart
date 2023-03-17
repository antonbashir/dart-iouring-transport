import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.debug,
        isolates: 1,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 1024,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: ringSetupSqpoll,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        maxConnections: 1024,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        defaultPool: 512,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 1024,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
      );
}
