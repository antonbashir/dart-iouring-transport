import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        ringSize: 16536,
        slabSize: 16 * 1024 * 1024,
        memoryQuota: 8 * 1024 * 1024 * 1024,
        slabAllocationMinimalObjectSize: 16,
        slabAllocationGranularity: 8,
        slabAllocationFactor: 1.05,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        bufferInitialCapacity: 16320,
        bufferLimit: 18 * 16320,
        bufferAvailableAwaitDelayed: Duration.zero,
        payloadBufferSize: 64,
      );

  static TransportControllerConfiguration controller() => TransportControllerConfiguration(
        cqesSize: 2048,
        batchMessageLimit: 1024,
        internalRingSize: 4096,
      );

  static TransportConnectionConfiguration connection() => TransportConnectionConfiguration();
}
