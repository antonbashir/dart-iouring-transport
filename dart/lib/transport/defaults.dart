import 'configuration.dart';
import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.debug,
        listenerIsolates: 1,
        workerInsolates: 1,
      );

  static TransportListenerConfiguration listener() => TransportListenerConfiguration(
        ringSize: 32768,
        ringFlags: ringSetupDeferTaskrun | ringSetupTaskrunFlag | ringSetupSingleIssuer,
      );

  static TransportWorkerConfiguration worker() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 32768,
        ringFlags: ringSetupSqpoll | ringSetupDeferTaskrun | ringSetupTaskrunFlag | ringSetupSingleIssuer,
      );

  static TransportClientConfiguration client() => TransportClientConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        defaultPool: 8,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
      );
}
