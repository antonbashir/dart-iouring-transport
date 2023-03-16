import 'package:iouring_transport/transport/constants.dart';

class TransportConfiguration {
  final TransportLogLevel logLevel;
  final int inboundIsolates;
  final int outboundIsolates;

  TransportConfiguration({
    required this.logLevel,
    required this.inboundIsolates,
    required this.outboundIsolates,
  });

  TransportConfiguration copyWith({
    TransportLogLevel? logLevel,
    int? inboundIsolates,
    int? outboundInsolates,
  }) =>
      TransportConfiguration(
        logLevel: logLevel ?? this.logLevel,
        inboundIsolates: inboundIsolates ?? this.inboundIsolates,
        outboundIsolates: outboundInsolates ?? this.outboundIsolates,
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
    int? ringSize,
    int? ringFlags,
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
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
  final int maxConnections;
  final int receiveBufferSize;
  final int sendBufferSize;
  final int defaultPool;

  TransportConnectorConfiguration({
    required this.maxConnections,
    required this.receiveBufferSize,
    required this.sendBufferSize,
    required this.defaultPool,
  });

  TransportConnectorConfiguration copyWith({
    int? maxConnections,
    int? receiveBufferSize,
    int? sendBufferSize,
    int? defaultPool,
  }) =>
      TransportConnectorConfiguration(
        maxConnections: maxConnections ?? this.maxConnections,
        receiveBufferSize: receiveBufferSize ?? this.receiveBufferSize,
        sendBufferSize: sendBufferSize ?? this.sendBufferSize,
        defaultPool: defaultPool ?? this.defaultPool,
      );
}
