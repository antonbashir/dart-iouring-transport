class TransportConfiguration {
  final int ringSize;
  final int slabSize;
  final int memoryQuota;
  final int slabAllocationMinimalObjectSize;
  final int slabAllocationGranularity;
  final double slabAllocationFactor;

  TransportConfiguration({
    required this.ringSize,
    required this.slabSize,
    required this.memoryQuota,
    required this.slabAllocationMinimalObjectSize,
    required this.slabAllocationGranularity,
    required this.slabAllocationFactor,
  });

  TransportConfiguration copyWith({
    int? ringSize,
    int? slabSize,
    int? memoryQuota,
    int? bufferInitialCapacity,
    int? bufferLimit,
    int? slabAllocationMinimalObjectSize,
    int? slabAllocationGranularity,
    double? slabAllocationFactor,
  }) =>
      TransportConfiguration(
        ringSize: ringSize ?? this.ringSize,
        slabSize: slabSize ?? this.slabSize,
        memoryQuota: memoryQuota ?? this.memoryQuota,
        slabAllocationMinimalObjectSize: slabAllocationMinimalObjectSize ?? this.slabAllocationMinimalObjectSize,
        slabAllocationGranularity: slabAllocationGranularity ?? this.slabAllocationGranularity,
        slabAllocationFactor: slabAllocationFactor ?? this.slabAllocationFactor,
      );
}

class TransportChannelConfiguration {
  final int bufferInitialCapacity;
  final int bufferLimit;
  final int messageSize;
  final Duration bufferAvailableAwaitDelayed;

  TransportChannelConfiguration({
    required this.bufferInitialCapacity,
    required this.bufferLimit,
    required this.bufferAvailableAwaitDelayed,
    required this.messageSize,
  });

  TransportChannelConfiguration copyWith({
    int? bufferInitialCapacity,
    int? bufferLimit,
    Duration? bufferAvailableAwaitDelayed,
    int? messageSize,
  }) =>
      TransportChannelConfiguration(
        bufferInitialCapacity: bufferInitialCapacity ?? this.bufferInitialCapacity,
        bufferLimit: bufferLimit ?? this.bufferLimit,
        bufferAvailableAwaitDelayed: bufferAvailableAwaitDelayed ?? this.bufferAvailableAwaitDelayed,
        messageSize: messageSize ?? this.messageSize,
      );
}

class TransportLoopConfiguration {
  final int initialEmptyCycles;
  final int maxEmptyCycles;
  final int emptyCyclesMultiplier;
  final Duration regularSleepDelay;
  final Duration maxSleepDelay;
  final int cqesSize;

  TransportLoopConfiguration({
    required this.initialEmptyCycles,
    required this.maxEmptyCycles,
    required this.emptyCyclesMultiplier,
    required this.regularSleepDelay,
    required this.maxSleepDelay,
    required this.cqesSize,
  });

  TransportLoopConfiguration copyWith({
    int? initialEmptyCycles,
    int? maxEmptyCycles,
    int? emptyCyclesMultiplier,
    Duration? regularSleepDelay,
    Duration? maxSleepDelay,
    int? cqesSize,
  }) =>
      TransportLoopConfiguration(
        initialEmptyCycles: initialEmptyCycles ?? this.initialEmptyCycles,
        maxEmptyCycles: maxEmptyCycles ?? this.maxEmptyCycles,
        emptyCyclesMultiplier: emptyCyclesMultiplier ?? this.emptyCyclesMultiplier,
        regularSleepDelay: regularSleepDelay ?? this.regularSleepDelay,
        maxSleepDelay: maxSleepDelay ?? this.maxSleepDelay,
        cqesSize: cqesSize ?? this.cqesSize,
      );
}
