import 'package:retry/retry.dart';

class TransportWorkerConfiguration {
  final int buffersCount;
  final int bufferSize;
  final int ringSize;
  final int ringFlags;
  final Duration timeoutCheckerPeriod;
  final double randomizationFactor;
  final Duration delayFactor;
  final Duration maxDelay;
  final Duration maxActiveTime;

  TransportWorkerConfiguration({
    required this.buffersCount,
    required this.bufferSize,
    required this.ringSize,
    required this.ringFlags,
    required this.timeoutCheckerPeriod,
    required this.randomizationFactor,
    required this.delayFactor,
    required this.maxDelay,
    required this.maxActiveTime,
  });

  TransportWorkerConfiguration copyWith({
    int? buffersCount,
    int? bufferSize,
    int? ringSize,
    int? ringFlags,
    Duration? timeoutCheckerPeriod,
    double? randomizationFactor,
    Duration? delayFactor,
    Duration? maxDelay,
    Duration? maxActiveTime,
  }) =>
      TransportWorkerConfiguration(
        buffersCount: buffersCount ?? this.buffersCount,
        bufferSize: bufferSize ?? this.bufferSize,
        ringSize: ringSize ?? this.ringSize,
        ringFlags: ringFlags ?? this.ringFlags,
        timeoutCheckerPeriod: timeoutCheckerPeriod ?? this.timeoutCheckerPeriod,
        randomizationFactor: randomizationFactor ?? this.randomizationFactor,
        delayFactor: delayFactor ?? this.delayFactor,
        maxDelay: maxDelay ?? this.maxDelay,
        maxActiveTime: maxActiveTime ?? this.maxActiveTime,
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

class TransportRetryConfiguration {
  final Duration delayFactor;
  final double randomizationFactor;
  final Duration maxDelay;
  final int maxAttempts;
  final bool Function(Exception exception) predicate;
  final void Function(Exception exception)? onRetry;

  late final RetryOptions options;

  TransportRetryConfiguration({
    required this.delayFactor,
    required this.randomizationFactor,
    required this.maxDelay,
    required this.maxAttempts,
    required this.predicate,
    this.onRetry,
  }) {
    options = RetryOptions(
      delayFactor: delayFactor,
      randomizationFactor: randomizationFactor,
      maxDelay: maxDelay,
      maxAttempts: maxAttempts,
    );
  }

  TransportRetryConfiguration copyWith({
    Duration? delayFactor,
    double? randomizationFactor,
    Duration? maxDelay,
    int? maxAttempts,
    bool Function(Exception exception)? predicate,
    void Function(Exception exception)? onRetry,
  }) =>
      TransportRetryConfiguration(
        delayFactor: delayFactor ?? this.delayFactor,
        randomizationFactor: randomizationFactor ?? this.randomizationFactor,
        maxDelay: maxDelay ?? this.maxDelay,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        predicate: predicate ?? this.predicate,
        onRetry: onRetry ?? this.onRetry,
      );
}
