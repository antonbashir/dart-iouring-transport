class TransportConfiguration {
  final int ringSize;

  TransportConfiguration({required this.ringSize});

  TransportConfiguration copyWith({int? ringSize}) => TransportConfiguration(ringSize: ringSize ?? this.ringSize);
}

class TransportChannelConfiguration {
  final int initialEmptyCycles;
  final int maxEmptyCycles;
  final int emptyCyclesMultiplier;
  final int regularSleepMillis;
  final int maxSleepMillis;
  final int cqesSize;

  TransportChannelConfiguration({
    required this.initialEmptyCycles,
    required this.maxEmptyCycles,
    required this.emptyCyclesMultiplier,
    required this.regularSleepMillis,
    required this.maxSleepMillis,
    required this.cqesSize,
  });

  TransportChannelConfiguration copyWith({
    int? initialEmptyCycles,
    int? maxEmptyCycles,
    int? emptyCyclesMultiplier,
    int? regularSleepSeconds,
    int? maxSleepSeconds,
    int? cqesSize,
  }) =>
      TransportChannelConfiguration(
        initialEmptyCycles: initialEmptyCycles ?? this.initialEmptyCycles,
        maxEmptyCycles: maxEmptyCycles ?? this.maxEmptyCycles,
        emptyCyclesMultiplier: emptyCyclesMultiplier ?? this.emptyCyclesMultiplier,
        regularSleepMillis: regularSleepSeconds ?? this.regularSleepMillis,
        maxSleepMillis: maxSleepSeconds ?? this.maxSleepMillis,
        cqesSize: cqesSize ?? this.cqesSize,
      );
}
