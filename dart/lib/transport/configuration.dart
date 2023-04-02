import 'constants.dart';

class TransportConfiguration {
  final TransportLogLevel logLevel;
  final int listenerIsolates;
  final int workerInsolates;

  TransportConfiguration({
    required this.logLevel,
    required this.listenerIsolates,
    required this.workerInsolates,
  });

  TransportConfiguration copyWith({
    TransportLogLevel? logLevel,
    int? listenerIsolates,
    int? workerInsolates,
  }) =>
      TransportConfiguration(
        logLevel: logLevel ?? this.logLevel,
        listenerIsolates: listenerIsolates ?? this.listenerIsolates,
        workerInsolates: workerInsolates ?? this.workerInsolates,
      );
}

class TransportListenerConfiguration {
  final int ringSize;
  final int ringFlags;

  TransportListenerConfiguration({
    required this.ringSize,
    required this.ringFlags,
  });

  TransportListenerConfiguration copyWith({
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportListenerConfiguration(
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
      );
}

class TransportWorkerConfiguration {
  final int buffersCount;
  final int bufferSize;
  final int ringSize;
  final int ringFlags;

  TransportWorkerConfiguration({
    required this.buffersCount,
    required this.bufferSize,
    required this.ringSize,
    required this.ringFlags,
  });

  TransportWorkerConfiguration copyWith({
    int? buffersCount,
    int? bufferSize,
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportWorkerConfiguration(
        buffersCount: buffersCount ?? this.buffersCount,
        bufferSize: bufferSize ?? this.bufferSize,
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
      );
}

class TransportServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportClientConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;
  final int defaultPool;

  TransportClientConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.defaultPool,
  });

  TransportClientConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    int? defaultPool,
  }) =>
      TransportClientConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        defaultPool: defaultPool ?? this.defaultPool,
      );
}
