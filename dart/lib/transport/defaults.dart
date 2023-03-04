import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        ringSize: 8192,
        slabSize: 16 * 1024 * 1024,
        memoryQuota: 2 * 1024 * 1024 * 1024,
        slabAllocationMinimalObjectSize: 32,
        slabAllocationGranularity: 8,
        slabAllocationFactor: 1.05,
        logColored: true,
        logLevel: 0,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        buffersCount: 1024,
        bufferSize: 4096,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        backlog: 512,
        ringSize: 2048,
      );

  static TransportConnectorConfiguration connector() => TransportConnectorConfiguration(
        ringSize: 2048,
      );
}
