import 'package:iouring_transport/transport/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration configuration() => TransportConfiguration(ringSize: 33554432);

  static TransportChannelConfiguration channel() => TransportChannelConfiguration(
        maxSleepMillis: 1,
        regularSleepMillis: 0,
        maxEmptyCycles: 1000000,
        emptyCyclesMultiplier: 2,
        initialEmptyCycles: 1000,
      );
}
