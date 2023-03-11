

class TransportConfiguration {
  final int logLevel;

  TransportConfiguration({
    required this.logLevel,
  });

  TransportConfiguration copyWith({
    int? logLevel,
  }) =>
      TransportConfiguration(
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
  final int ringSize;
  final int ringFlags;
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportAcceptorConfiguration({
    required this.ringSize,
    required this.ringFlags,
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportAcceptorConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportAcceptorConfiguration(
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
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
