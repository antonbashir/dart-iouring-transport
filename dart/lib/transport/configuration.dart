import 'package:iouring_transport/transport/constants.dart';

class TransportConfiguration {
  final TransportLogLevel logLevel;

  TransportConfiguration({
    required this.logLevel,
  });

  TransportConfiguration copyWith({
    TransportLogLevel? logLevel,
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

class TransportEventLoopConfiguration {
  final int ringSize;
  final int ringFlags;
  final int clientMaxConnections;
  final int clientReceiveBufferSize;
  final int clientSendBufferSize;

  TransportEventLoopConfiguration({
    required this.ringSize,
    required this.ringFlags,
    required this.clientMaxConnections,
    required this.clientReceiveBufferSize,
    required this.clientSendBufferSize,
  });

  TransportEventLoopConfiguration copyWith({
    int? clientMaxConnections,
    int? clientReceiveBufferSize,
    int? clientSendBufferSize,
    int? ringSize,
    int? ringFlags,
  }) =>
      TransportEventLoopConfiguration(
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
        clientMaxConnections: clientMaxConnections ?? this.clientMaxConnections,
        clientReceiveBufferSize: clientReceiveBufferSize ?? this.clientReceiveBufferSize,
        clientSendBufferSize: clientSendBufferSize ?? this.clientSendBufferSize,
      );
}
