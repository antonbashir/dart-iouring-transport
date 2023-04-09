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
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportTcpServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportTcpServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportTcpServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUdpServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUdpServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUdpServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUdpServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUnixStreamServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUnixStreamServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUnixStreamServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUnixStreamServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUnixDatagramServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUnixDatagramServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUnixDatagramServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUnixDatagramServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportTcpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportTcpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportTcpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportTcpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUdpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUdpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUdpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUdpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUnixStreamClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUnixStreamClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUnixStreamClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUnixStreamClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}

class TransportUnixDatagramClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;

  TransportUnixDatagramClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
  });

  TransportUnixDatagramClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) =>
      TransportUnixDatagramClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
      );
}
