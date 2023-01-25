import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration configuration() => TransportConfiguration(
        ringSize: 32768,
        slabSize: 16 * 1024 * 1024,
        memoryQuota: 1 * 1024 * 1024 * 1024 * 1024,
        slabAllocationMinimalObjectSize: 16,
        slabAllocationGranularity: 8,
        slabAllocationFactor: 1.05,
      );

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        bufferInitialCapacity: 16320,
        bufferLimit: 18 * 16320,
        bufferAvailableAwaitDelayed: Duration(milliseconds: 1),
      );

  static TransportLoopConfiguration loop() => TransportLoopConfiguration(
        maxSleepMillis: 10,
        regularSleepMillis: 0,
        maxEmptyCycles: 10000000,
        emptyCyclesMultiplier: 2,
        initialEmptyCycles: 1000,
        cqesSize: 32768,
      );
}
