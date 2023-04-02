import 'dart:io';

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
        ringFlags: 0,
      );

  static TransportWorkerConfiguration inboundWorker() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 32768,
        ringFlags: ringSetupSqpoll,
      );

  static TransportWorkerConfiguration outboundWorker() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 32768,
        ringFlags: ringSetupSqpoll,
      );

  static TransportClientConfiguration client() => TransportClientConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
        defaultPool: 1,
      );

  static TransportServerConfiguration server() => TransportServerConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );
}
