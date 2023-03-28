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
        ringFlags: 0,
      );

  static TransportWorkerConfiguration worker() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 32768,
        ringFlags: ringSetupSqpoll | ringSetupSingleIssuer,
      );

  static TransportClientConfiguration client() => TransportClientConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
        defaultPool: 1,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4096,
        sendBufferSize: 4096,
      );
}
