class TransportConfiguration {
  final int ringSize;
  final int slabSize;
  final int memoryQuota;
  final int slabAllocationMinimalObjectSize;
  final int slabAllocationGranularity;
  final double slabAllocationFactor;
  final int logLevel;
  final bool logColored;

  TransportConfiguration({
    required this.ringSize,
    required this.slabSize,
    required this.memoryQuota,
    required this.slabAllocationMinimalObjectSize,
    required this.slabAllocationGranularity,
    required this.slabAllocationFactor,
    required this.logLevel,
    required this.logColored,
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
    int? logLevel,
    bool? logColored,
  }) =>
      TransportConfiguration(
        ringSize: ringSize ?? this.ringSize,
        slabSize: slabSize ?? this.slabSize,
        memoryQuota: memoryQuota ?? this.memoryQuota,
        slabAllocationMinimalObjectSize: slabAllocationMinimalObjectSize ?? this.slabAllocationMinimalObjectSize,
        slabAllocationGranularity: slabAllocationGranularity ?? this.slabAllocationGranularity,
        slabAllocationFactor: slabAllocationFactor ?? this.slabAllocationFactor,
        logColored: logColored ?? this.logColored,
        logLevel: logLevel ?? this.logLevel,
      );
}

class TransportChannelConfiguration {
  final int bufferSize;
  final int buffersCount;
  final int ringSize;
  final int bufferShift;

  TransportChannelConfiguration({
    required this.bufferSize,
    required this.buffersCount,
    required this.bufferShift,
    required this.ringSize,
  });

  TransportChannelConfiguration copyWith({
    int? bufferSize,
    int? buffersCount,
    int? ringSize,
    int? bufferShift,
  }) =>
      TransportChannelConfiguration(
        bufferSize: bufferSize ?? this.bufferSize,
        buffersCount: buffersCount ?? this.buffersCount,
        ringSize: ringSize ?? this.ringSize,
        bufferShift: bufferShift ?? this.bufferShift,
      );
}

class TransportControllerConfiguration {
  final int retryMaxCount;
  final int internalRingSize;

  TransportControllerConfiguration({
    required this.retryMaxCount,
    required this.internalRingSize,
  });

  TransportControllerConfiguration copyWith({
    int? retryMaxCount,
    int? internalRingSize,
  }) =>
      TransportControllerConfiguration(
        retryMaxCount: retryMaxCount ?? this.retryMaxCount,
        internalRingSize: internalRingSize ?? this.internalRingSize,
      );
}

class TransportAcceptorConfiguration {
  final int backlog;
  final int ringSize;

  TransportAcceptorConfiguration({
    required this.backlog,
    required this.ringSize,
  });

  TransportAcceptorConfiguration copyWith({
    int? backlog,
    int? ringSize,
  }) =>
      TransportAcceptorConfiguration(backlog: backlog ?? this.backlog, ringSize: ringSize ?? this.ringSize);
}

class TransportConnectorConfiguration {
  final int ringSize;

  TransportConnectorConfiguration({
    required this.ringSize,
  });

  TransportConnectorConfiguration copyWith({
    int? ringSize,
  }) =>
      TransportConnectorConfiguration(ringSize: ringSize ?? this.ringSize);
}
