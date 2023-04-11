import 'constants.dart';

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

class TransportUdpMulticastConfiguration {
  final String groupAddress;
  final String localAddress;
  final String? localInterface;
  final int? interfaceIndex;
  final bool calculateInterfaceIndex;

  TransportUdpMulticastConfiguration._(
    this.groupAddress,
    this.localAddress,
    this.localInterface,
    this.interfaceIndex,
    this.calculateInterfaceIndex,
  );

  factory TransportUdpMulticastConfiguration.byInterfaceIndex({required String groupAddress, required String localAddress, required int interfaceIndex}) {
    return TransportUdpMulticastConfiguration._(groupAddress, localAddress, null, interfaceIndex, false);
  }

  factory TransportUdpMulticastConfiguration.byInterfaceName({required String groupAddress, required String localAddress, required String interfaceName}) {
    return TransportUdpMulticastConfiguration._(groupAddress, localAddress, interfaceName, -1, true);
  }
}

class TransportUdpMulticastSourceConfiguration {
  final String groupAddress;
  final String localAddress;
  final String sourceAddress;

  TransportUdpMulticastSourceConfiguration({
    required this.groupAddress,
    required this.localAddress,
    required this.sourceAddress,
  });
}

class TransportUdpMulticastManager {
  void Function(TransportUdpMulticastConfiguration configuration) _onAddMembership = (configuration) => {};
  void Function(TransportUdpMulticastConfiguration configuration) _onDropMembership = (configuration) => {};
  void Function(TransportUdpMulticastSourceConfiguration configuration) _onAddSourceMembership = (configuration) => {};
  void Function(TransportUdpMulticastSourceConfiguration configuration) _onDropSourceMembership = (configuration) => {};

  void subscribe(
      {required void Function(TransportUdpMulticastConfiguration configuration) onAddMembership,
      required void Function(TransportUdpMulticastConfiguration configuration) onDropMembership,
      required void Function(TransportUdpMulticastSourceConfiguration configuration) onAddSourceMembership,
      required void Function(TransportUdpMulticastSourceConfiguration configuration) onDropSourceMembership}) {
    _onAddMembership = onAddMembership;
    _onDropMembership = onDropMembership;
    _onAddSourceMembership = onAddSourceMembership;
    _onDropSourceMembership = onDropSourceMembership;
  }

  void addMembership(TransportUdpMulticastConfiguration configuration) => _onAddMembership(configuration);

  void dropMembership(TransportUdpMulticastConfiguration configuration) => _onDropMembership(configuration);

  void addSourceMembership(TransportUdpMulticastSourceConfiguration configuration) => _onAddSourceMembership(configuration);

  void dropSourceMembership(TransportUdpMulticastSourceConfiguration configuration) => _onDropSourceMembership(configuration);
}

class TransportTcpServerConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketMaxConnections;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketKeepalive;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;
  final int? ipTtl;
  final bool? ipFreebind;
  final bool? tcpQuickack;
  final bool? tcpDeferAccept;
  final bool? tcpFastopen;
  final int? tcpKeepAliveIdle;
  final int? tcpKeepAliveMaxCount;
  final int? tcpKeepAliveIndividualCount;
  final int? tcpMaxSegmentSize;
  final bool? tcpNodelay;
  final int? tcpSynCount;

  TransportTcpServerConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketMaxConnections,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketKeepalive,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
    this.ipTtl,
    this.ipFreebind,
    this.tcpQuickack,
    this.tcpDeferAccept,
    this.tcpFastopen,
    this.tcpKeepAliveIdle,
    this.tcpKeepAliveMaxCount,
    this.tcpKeepAliveIndividualCount,
    this.tcpMaxSegmentSize,
    this.tcpNodelay,
    this.tcpSynCount,
  });

  TransportTcpServerConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketMaxConnections,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    bool? socketKeepalive,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
    int? ipTtl,
    bool? ipFreebind,
    bool? tcpQuickack,
    bool? tcpDeferAccept,
    bool? tcpFastopen,
    int? tcpKeepAliveIdle,
    int? tcpKeepAliveMaxCount,
    int? tcpKeepAliveIndividualCount,
    int? tcpMaxSegmentSize,
    bool? tcpNodelay,
    int? tcpSynCount,
  }) =>
      TransportTcpServerConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketMaxConnections: socketMaxConnections ?? this.socketMaxConnections,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketKeepalive: socketKeepalive ?? this.socketKeepalive,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
        ipTtl: ipTtl ?? this.ipTtl,
        ipFreebind: ipFreebind ?? this.ipFreebind,
        tcpQuickack: tcpQuickack ?? this.tcpQuickack,
        tcpDeferAccept: tcpDeferAccept ?? this.tcpDeferAccept,
        tcpFastopen: tcpFastopen ?? this.tcpFastopen,
        tcpKeepAliveIdle: tcpKeepAliveIdle ?? this.tcpKeepAliveIdle,
        tcpKeepAliveMaxCount: tcpKeepAliveMaxCount ?? this.tcpKeepAliveMaxCount,
        tcpKeepAliveIndividualCount: tcpKeepAliveIndividualCount ?? this.tcpKeepAliveIndividualCount,
        tcpMaxSegmentSize: tcpMaxSegmentSize ?? this.tcpMaxSegmentSize,
        tcpNodelay: tcpNodelay ?? this.tcpNodelay,
        tcpSynCount: tcpSynCount ?? this.tcpSynCount,
      );
}

class TransportUdpServerConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketBroadcast;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;
  final int? ipTtl;
  final bool? ipFreebind;
  final bool? ipMulticastAll;
  final TransportUdpMulticastConfiguration? ipMulticastInterface;
  final int? ipMulticastLoop;
  final int? ipMulticastTtl;
  final TransportUdpMulticastManager? multicastManager;

  TransportUdpServerConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketBroadcast,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
    this.ipTtl,
    this.ipFreebind,
    this.ipMulticastAll,
    this.ipMulticastInterface,
    this.ipMulticastLoop,
    this.ipMulticastTtl,
    this.multicastManager,
  });

  TransportUdpServerConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    bool? socketBroadcast,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
    int? ipTtl,
    bool? ipFreebind,
    bool? ipMulticastAll,
    TransportUdpMulticastConfiguration? ipMulticastInterface,
    int? ipMulticastLoop,
    int? ipMulticastTtl,
    TransportUdpMulticastManager? multicastManager,
  }) =>
      TransportUdpServerConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketBroadcast: socketBroadcast ?? this.socketBroadcast,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
        ipTtl: ipTtl ?? this.ipTtl,
        ipFreebind: ipFreebind ?? this.ipFreebind,
        ipMulticastAll: ipMulticastAll ?? this.ipMulticastAll,
        ipMulticastInterface: ipMulticastInterface ?? this.ipMulticastInterface,
        ipMulticastLoop: ipMulticastLoop ?? this.ipMulticastLoop,
        ipMulticastTtl: ipMulticastTtl ?? this.ipMulticastTtl,
        multicastManager: multicastManager ?? this.multicastManager,
      );
}

class TransportUnixStreamServerConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketMaxConnections;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketKeepalive;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;

  TransportUnixStreamServerConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketMaxConnections,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketKeepalive,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
  });

  TransportUnixStreamServerConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketMaxConnections,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    bool? socketKeepalive,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
  }) =>
      TransportUnixStreamServerConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketMaxConnections: socketMaxConnections ?? this.socketMaxConnections,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketKeepalive: socketKeepalive ?? this.socketKeepalive,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
      );
}

class TransportUnixDatagramServerConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;

  TransportUnixDatagramServerConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
  });

  TransportUnixDatagramServerConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
  }) =>
      TransportUnixDatagramServerConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
      );
}

class TransportTcpClientConfiguration {
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketKeepalive;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;
  final int? ipTtl;
  final bool? ipFreebind;
  final bool? tcpQuickack;
  final bool? tcpDeferAccept;
  final bool? tcpFastopen;
  final int? tcpKeepAliveIdle;
  final int? tcpKeepAliveMaxCount;
  final int? tcpKeepAliveIndividualCount;
  final int? tcpMaxSegmentSize;
  final bool? tcpNodelay;
  final int? tcpSynCount;

  TransportTcpClientConfiguration({
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketKeepalive,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
    this.ipTtl,
    this.ipFreebind,
    this.tcpQuickack,
    this.tcpDeferAccept,
    this.tcpFastopen,
    this.tcpKeepAliveIdle,
    this.tcpKeepAliveMaxCount,
    this.tcpKeepAliveIndividualCount,
    this.tcpMaxSegmentSize,
    this.tcpNodelay,
    this.tcpSynCount,
  });

  TransportTcpClientConfiguration copyWith({
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    bool? socketKeepalive,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
    int? ipTtl,
    bool? ipFreebind,
    bool? tcpQuickack,
    bool? tcpDeferAccept,
    bool? tcpFastopen,
    int? tcpKeepAliveIdle,
    int? tcpKeepAliveMaxCount,
    int? tcpKeepAliveIndividualCount,
    int? tcpMaxSegmentSize,
    bool? tcpNodelay,
    int? tcpSynCount,
  }) =>
      TransportTcpClientConfiguration(
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketKeepalive: socketKeepalive ?? this.socketKeepalive,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
        ipTtl: ipTtl ?? this.ipTtl,
        ipFreebind: ipFreebind ?? this.ipFreebind,
        tcpQuickack: tcpQuickack ?? this.tcpQuickack,
        tcpDeferAccept: tcpDeferAccept ?? this.tcpDeferAccept,
        tcpFastopen: tcpFastopen ?? this.tcpFastopen,
        tcpKeepAliveIdle: tcpKeepAliveIdle ?? this.tcpKeepAliveIdle,
        tcpKeepAliveMaxCount: tcpKeepAliveMaxCount ?? this.tcpKeepAliveMaxCount,
        tcpKeepAliveIndividualCount: tcpKeepAliveIndividualCount ?? this.tcpKeepAliveIndividualCount,
        tcpMaxSegmentSize: tcpMaxSegmentSize ?? this.tcpMaxSegmentSize,
        tcpNodelay: tcpNodelay ?? this.tcpNodelay,
        tcpSynCount: tcpSynCount ?? this.tcpSynCount,
      );
}

class TransportUdpClientConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketBroadcast;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;
  final int? ipTtl;
  final bool? ipFreebind;
  final bool? ipMulticastAll;
  final TransportUdpMulticastConfiguration? ipMulticastInterface;
  final int? ipMulticastLoop;
  final int? ipMulticastTtl;
  final TransportUdpMulticastManager? multicastManager;

  TransportUdpClientConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketBroadcast,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
    this.ipTtl,
    this.ipFreebind,
    this.ipMulticastAll,
    this.ipMulticastInterface,
    this.ipMulticastLoop,
    this.ipMulticastTtl,
    this.multicastManager,
  });

  TransportUdpClientConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    bool? socketBroadcast,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
    int? ipTtl,
    bool? ipFreebind,
    bool? ipMulticastAll,
    TransportUdpMulticastConfiguration? ipMulticastInterface,
    int? ipMulticastLoop,
    int? ipMulticastTtl,
    TransportUdpMulticastManager? multicastManager,
  }) =>
      TransportUdpClientConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketBroadcast: socketBroadcast ?? this.socketBroadcast,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
        ipTtl: ipTtl ?? this.ipTtl,
        ipFreebind: ipFreebind ?? this.ipFreebind,
        ipMulticastAll: ipMulticastAll ?? this.ipMulticastAll,
        ipMulticastInterface: ipMulticastInterface ?? this.ipMulticastInterface,
        ipMulticastLoop: ipMulticastLoop ?? this.ipMulticastLoop,
        ipMulticastTtl: ipMulticastTtl ?? this.ipMulticastTtl,
        multicastManager: multicastManager ?? this.multicastManager,
      );
}

class TransportUnixStreamClientConfiguration {
  final int pool;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final bool? socketKeepalive;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;

  TransportUnixStreamClientConfiguration({
    required this.pool,
    required this.connectTimeout,
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketKeepalive,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
  });

  TransportUnixStreamClientConfiguration copyWith({
    int? pool,
    Duration? connectTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
  }) =>
      TransportUnixStreamClientConfiguration(
        pool: pool ?? this.pool,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketKeepalive: socketKeepalive ?? this.socketKeepalive,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
      );
}

class TransportUnixDatagramClientConfiguration {
  final Duration readTimeout;
  final Duration writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketClockexec;
  final bool? socketReuseAddress;
  final bool? socketReusePort;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;

  TransportUnixDatagramClientConfiguration({
    required this.readTimeout,
    required this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketClockexec,
    this.socketReuseAddress,
    this.socketReusePort,
    this.socketReceiveLowAt,
    this.socketSendLowAt,
  });

  TransportUnixDatagramClientConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketClockexec,
    bool? socketReuseAddress,
    bool? socketReusePort,
    int? socketReceiveLowAt,
    int? socketSendLowAt,
  }) =>
      TransportUnixDatagramClientConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketClockexec: socketClockexec ?? this.socketClockexec,
        socketReuseAddress: socketReuseAddress ?? this.socketReuseAddress,
        socketReusePort: socketReusePort ?? this.socketReusePort,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
      );
}
