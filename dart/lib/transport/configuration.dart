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
  final int payloadBufferSize;
  final Duration bufferAvailableAwaitDelayed;

  TransportChannelConfiguration({
    required this.bufferInitialCapacity,
    required this.bufferLimit,
    required this.bufferAvailableAwaitDelayed,
    required this.payloadBufferSize,
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
        payloadBufferSize: messageSize ?? this.payloadBufferSize,
      );
}

class TransportControllerConfiguration {
  final int cqesSize;

  TransportControllerConfiguration({
    required this.cqesSize,
  });

  TransportControllerConfiguration copyWith({
    int? cqesSize,
  }) =>
      TransportControllerConfiguration(
        cqesSize: cqesSize ?? this.cqesSize,
      );
}

class TransportConnectionConfiguration {
  TransportConnectionConfiguration();

  TransportConnectionConfiguration copyWith() => TransportConnectionConfiguration();
}
