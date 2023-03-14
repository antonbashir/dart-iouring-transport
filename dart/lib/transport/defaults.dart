import 'package:iouring_transport/transport/configuration.dart';

import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.info,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 8192,
        bufferSize: 4096,
        ringSize: 16536,
        ringFlags: ringSetupSqpoll,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 1024,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
        ringSize: 2048,
        ringFlags: 0,
      );
}
