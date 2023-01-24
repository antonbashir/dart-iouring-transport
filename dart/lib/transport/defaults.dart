import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration configuration() => TransportConfiguration(
        ringSize: 1024,
        slabSize: 16 * 1024 * 1024,
        memoryQuota: 1 * 1024 * 1024 * 1024,
        slabAllocationMinimalObjectSize: 16,
        slabAllocationGranularity: 8,
        slabAllocationFactor: 1.05,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        bufferInitialCapacity: 16320,
        bufferLimit: 16 * 16320,
      );

  static TransportLoopConfiguration loop() => TransportLoopConfiguration(
        maxSleepMillis: 1,
        regularSleepMillis: 0,
        maxEmptyCycles: 1000000,
        emptyCyclesMultiplier: 2,
        initialEmptyCycles: 1000,
        cqesSize: 512,
      );
}
