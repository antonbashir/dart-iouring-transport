import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        ringSize: 1024,
        slabSize: 16 * 1024 * 1024,
        memoryQuota: 1 * 1024 * 1024 * 1024,
        slabAllocationMinimalObjectSize: 16,
        slabAllocationGranularity: 8,
        slabAllocationFactor: 1.05,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        bufferInitialCapacity: 16320,
        bufferLimit: 18 * 16320,
        bufferAvailableAwaitDelayed: Duration.zero,
        payloadBufferSize: 1024,
      );

  static TransportListenerConfiguration listener() => TransportListenerConfiguration(
        cqesSize: 512,
      );

  static TransportConnectionConfiguration connection() => TransportConnectionConfiguration();
}
