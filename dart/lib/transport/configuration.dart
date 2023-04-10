class TransportConfiguration {
  final int listenerIsolates;
  final int workerInsolates;

  TransportConfiguration({
    required this.listenerIsolates,
    required this.workerInsolates,
  });

  TransportConfiguration copyWith({
    int? listenerIsolates,
    int? workerInsolates,
  }) =>
      TransportConfiguration(
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

class TransportRetryConfiguration {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffFactor;

  TransportRetryConfiguration({
    required this.initialDelay,
    required this.maxDelay,
    required this.maxRetries,
    required this.backoffFactor,
  });

  TransportRetryConfiguration copyWith({
    int? maxRetries,
    Duration? initialDelay,
    Duration? maxDelay,
    double? backoffFactor,
  }) =>
      TransportRetryConfiguration(
        maxRetries: maxRetries ?? this.maxRetries,
        initialDelay: initialDelay ?? this.initialDelay,
        maxDelay: maxDelay ?? this.maxDelay,
        backoffFactor: backoffFactor ?? this.backoffFactor,
      );
}

class TransportTcpServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportTcpServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportTcpServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportTcpServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUdpServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUdpServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUdpServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUdpServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUnixStreamServerConfiguration {
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUnixStreamServerConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUnixStreamServerConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUnixStreamServerConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUnixDatagramServerConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUnixDatagramServerConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUnixDatagramServerConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUnixDatagramServerConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportTcpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportTcpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportTcpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportTcpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUdpClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUdpClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUdpClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUdpClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUnixStreamClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUnixStreamClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUnixStreamClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUnixStreamClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}

class TransportUnixDatagramClientConfiguration {
  final int receiveBufferSize;
  final int sendBufferSize;
  final Duration readTimeout;
  final Duration writeTimeout;
  final TransportRetryConfiguration retryConfiguration;

  TransportUnixDatagramClientConfiguration({
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.readTimeout,
    required this.writeTimeout,
    required this.retryConfiguration,
  });

  TransportUnixDatagramClientConfiguration copyWith({
    int? receiveBufferSize,
    int? sendBufferSize,
    Duration? readTimeout,
    Duration? writeTimeout,
    TransportRetryConfiguration? retryConfiguration,
  }) =>
      TransportUnixDatagramClientConfiguration(
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        retryConfiguration: retryConfiguration ?? this.retryConfiguration,
      );
}
