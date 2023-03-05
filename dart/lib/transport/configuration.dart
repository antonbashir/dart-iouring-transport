class TransportConfiguration {
  final int logLevel;
  final bool logColored;

  TransportConfiguration({
    required this.logLevel,
    required this.logColored,
  });

  TransportConfiguration copyWith({
    int? bufferInitialCapacity,
    int? bufferLimit,
    int? logLevel,
    bool? logColored,
  }) =>
      TransportConfiguration(
        logColored: logColored ?? this.logColored,
        logLevel: logLevel ?? this.logLevel,
      );
}

class TransportChannelConfiguration {
  final int buffersCount;
  final int bufferSize;
  final int ringSize;
  final int ringFlags;

  TransportChannelConfiguration({
    required this.buffersCount,
    required this.bufferSize,
    required this.ringSize,
    required this.ringFlags,
  });

  TransportChannelConfiguration copyWith({
    int? buffersCount,
    int? bufferSize,
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportChannelConfiguration(
        buffersCount: buffersCount ?? this.buffersCount,
        bufferSize: bufferSize ?? this.bufferSize,
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
      );
}

class TransportAcceptorConfiguration {
  final int backlog;
  final int ringSize;
  final int ringFlags;

  TransportAcceptorConfiguration({
    required this.backlog,
    required this.ringSize,
    required this.ringFlags,
  });

  TransportAcceptorConfiguration copyWith({
    int? backlog,
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportAcceptorConfiguration(
        backlog: backlog ?? this.backlog,
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
      );
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
