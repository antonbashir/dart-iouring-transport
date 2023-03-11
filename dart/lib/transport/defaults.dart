import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: 0,
        channelPoolMode: TransportChannelPoolMode.LeastConnections,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 1024,
        bufferSize: 4096,
        ringSize: 16536,
        ringFlags: RingSetupSqpoll,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 1024,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
        ringSize: 2048,
        ringFlags: 0,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        ringSize: 2048,
      );
}
