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
        ringSize: 16384,
        ringFlags: 0,
      );

  static TransportWorkerConfiguration worker() => TransportWorkerConfiguration(
        buffersCount: 1024,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: 0,
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
