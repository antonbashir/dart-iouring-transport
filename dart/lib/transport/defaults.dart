import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logColored: true,
        logLevel: 0,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 8192,
        bufferSize: 4096,
        ringSize: 8192,
        ringFlags: RingSetupSqpoll,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        backlog: 1024,
        ringSize: 2048,
        ringFlags: 0,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        ringSize: 2048,
      );
}
