import '../configuration.dart';

class TransportTcpServerConfiguration {
  final Duration? readTimeout;
  final Duration? writeTimeout;
  final int? socketMaxConnections;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketCloexec;
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
  final bool? tcpNoDelay;
  final int? tcpSynCount;

  TransportTcpServerConfiguration({
    this.readTimeout,
    this.writeTimeout,
    this.socketMaxConnections,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketCloexec,
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
    this.tcpNoDelay,
    this.tcpSynCount,
  });

  TransportTcpServerConfiguration copyWith({
    Duration? readTimeout,
    Duration? writeTimeout,
    int? socketMaxConnections,
    int? socketReceiveBufferSize,
    int? socketSendBufferSize,
    bool? socketNonblock,
    bool? socketCloexec,
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
    bool? tcpNoDelay,
    int? tcpSynCount,
  }) =>
      TransportTcpServerConfiguration(
        readTimeout: readTimeout ?? this.readTimeout,
        writeTimeout: writeTimeout ?? this.writeTimeout,
        socketMaxConnections: socketMaxConnections ?? this.socketMaxConnections,
        socketReceiveBufferSize: socketReceiveBufferSize ?? this.socketReceiveBufferSize,
        socketSendBufferSize: socketSendBufferSize ?? this.socketSendBufferSize,
        socketNonblock: socketNonblock ?? this.socketNonblock,
        socketCloexec: socketCloexec ?? this.socketCloexec,
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
        tcpNoDelay: tcpNoDelay ?? this.tcpNoDelay,
        tcpSynCount: tcpSynCount ?? this.tcpSynCount,
      );
}

class TransportUdpServerConfiguration {
  final Duration? readTimeout;
  final Duration? writeTimeout;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketCloexec;
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
    this.readTimeout,
    this.writeTimeout,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketCloexec,
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
    bool? socketCloexec,
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
        socketCloexec: socketCloexec ?? this.socketCloexec,
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
  final Duration? readTimeout;
  final Duration? writeTimeout;
  final int? socketMaxConnections;
  final int? socketReceiveBufferSize;
  final int? socketSendBufferSize;
  final bool? socketNonblock;
  final bool? socketCloexec;
  final bool? socketKeepalive;
  final int? socketReceiveLowAt;
  final int? socketSendLowAt;

  TransportUnixStreamServerConfiguration({
    this.readTimeout,
    this.writeTimeout,
    this.socketMaxConnections,
    this.socketReceiveBufferSize,
    this.socketSendBufferSize,
    this.socketNonblock,
    this.socketCloexec,
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
    bool? socketCloexec,
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
        socketCloexec: socketCloexec ?? this.socketCloexec,
        socketKeepalive: socketKeepalive ?? this.socketKeepalive,
        socketReceiveLowAt: socketReceiveLowAt ?? this.socketReceiveLowAt,
        socketSendLowAt: socketSendLowAt ?? this.socketSendLowAt,
      );
}
