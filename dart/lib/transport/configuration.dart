import 'package:retry/retry.dart';

class TransportWorkerConfiguration {
  final int buffersCount;
  final int bufferSize;
  final int ringSize;
  final int ringFlags;
  final Duration timeoutCheckerPeriod;
  final double delayRandomizationFactor;
  final int cqePeekCount;
  final int cqeWaitCount;
  final Duration cqeWaitTimeout;
  final Duration baseDelay;
  final Duration maxDelay;
  final bool trace;

  TransportWorkerConfiguration({
    required this.buffersCount,
    required this.bufferSize,
    required this.ringSize,
    required this.ringFlags,
    required this.timeoutCheckerPeriod,
    required this.delayRandomizationFactor,
    required this.baseDelay,
    required this.maxDelay,
    required this.cqePeekCount,
    required this.cqeWaitCount,
    required this.cqeWaitTimeout,
    required this.trace,
  });

  TransportWorkerConfiguration copyWith({
    int? buffersCount,
    int? bufferSize,
    int? ringSize,
    int? ringFlags,
    Duration? timeoutCheckerPeriod,
    double? delayRandomizationFactor,
    Duration? baseDelay,
    Duration? maxDelay,
    int? cqePeekCount,
    int? cqeWaitCount,
    Duration? cqeWaitTimeout,
    bool? trace,
  }) =>
      TransportWorkerConfiguration(
        buffersCount: buffersCount ?? this.buffersCount,
        bufferSize: bufferSize ?? this.bufferSize,
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
        timeoutCheckerPeriod: timeoutCheckerPeriod ?? this.timeoutCheckerPeriod,
        delayRandomizationFactor: delayRandomizationFactor ?? this.delayRandomizationFactor,
        baseDelay: baseDelay ?? this.baseDelay,
        maxDelay: maxDelay ?? this.maxDelay,
        cqePeekCount: cqePeekCount ?? this.cqePeekCount,
        cqeWaitCount: cqeWaitCount ?? this.cqeWaitCount,
        cqeWaitTimeout: cqeWaitTimeout ?? this.cqeWaitTimeout,
        trace: trace ?? this.trace,
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

  factory TransportUdpMulticastConfiguration.byInterfaceIndex({
    required String groupAddress,
    required String localAddress,
    required int interfaceIndex,
  }) {
    return TransportUdpMulticastConfiguration._(groupAddress, localAddress, null, interfaceIndex, false);
  }

  factory TransportUdpMulticastConfiguration.byInterfaceName({
    required String groupAddress,
    required String localAddress,
    required String interfaceName,
  }) {
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

class TransportRetryConfiguration {
  final Duration baseDelay;
  final double randomizationFactor;
  final Duration maxDelay;
  final int maxAttempts;
  final bool Function(Exception exception) predicate;

  late final RetryOptions options;

  TransportRetryConfiguration({
    required this.baseDelay,
    required this.randomizationFactor,
    required this.maxDelay,
    required this.maxAttempts,
    required this.predicate,
  }) {
    options = RetryOptions(
      delayFactor: baseDelay,
      randomizationFactor: randomizationFactor,
      maxDelay: maxDelay,
      maxAttempts: maxAttempts,
    );
  }

  TransportRetryConfiguration copyWith({
    Duration? baseDelay,
    double? randomizationFactor,
    Duration? maxDelay,
    int? maxAttempts,
    bool Function(Exception exception)? predicate,
    void Function(Exception exception)? onRetry,
  }) =>
      TransportRetryConfiguration(
        baseDelay: baseDelay ?? this.baseDelay,
        randomizationFactor: randomizationFactor ?? this.randomizationFactor,
        maxDelay: maxDelay ?? this.maxDelay,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        predicate: predicate ?? this.predicate,
      );
}
