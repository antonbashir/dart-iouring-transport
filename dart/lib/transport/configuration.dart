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

class TransportTcpServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportTcpServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportTcpServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportTcpServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportUdpServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportUdpServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportUdpServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportUdpServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportUnixStreamServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportUnixStreamServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportUnixStreamServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportUnixStreamServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportUnixDatagramServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportUnixDatagramServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportUnixDatagramServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportUnixDatagramServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportTcpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;

  TransportTcpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
  });

  TransportTcpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
  }) =>
      TransportTcpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
      );
}

class TransportUdpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportUdpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportUdpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportUdpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}

class TransportUnixStreamClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;

  TransportUnixStreamClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
  });

  TransportUnixStreamClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
  }) =>
      TransportUnixStreamClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
      );
}

class TransportUnixDatagramClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;

  TransportUnixDatagramClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
  });

  TransportUnixDatagramClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
  }) =>
      TransportUnixDatagramClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
      );
}
