import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logColored: true,
        logLevel: 0,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 16536,
        bufferSize: 4096,
        ringSize: 16536,
        ringFlags: RingSetupSqpoll,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 16536,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        ringSize: 2048,
        ringFlags: 0,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        ringSize: 2048,
      );
}
