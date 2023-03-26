import 'configuration.dart';
import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        logLevel: TransportLogLevel.debug,
        listenerIsolates: 1,
        workerInsolates: 2,
      );

  static TransportListenerConfiguration listener() => TransportListenerConfiguration(
        ringSize: 32768,
        ringFlags: ringSetupCqe32 | ringSetupSqe128,
      );

  static TransportWorkerConfiguration worker() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 32768,
        ringFlags: ringSetupSqpoll | ringSetupCqe32 | ringSetupSqe128,
      );

  static TransportClientConfiguration client() => TransportClientConfiguration(
        maxConnections: 2048,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
        defaultPool: 1,
      );

  static TransportAcceptorConfiguration acceptor() => TransportAcceptorConfiguration(
        maxConnections: 2048,
        receiveBufferSize: 2048,
        sendBufferSize: 2048,
      );
}
