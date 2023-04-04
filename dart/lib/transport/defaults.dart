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
        ringSize: 16384,
        ringFlags: 0,
      );

  static TransportWorkerConfiguration inbound() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: ringSetupSqpoll,
      );

  static TransportWorkerConfiguration outbound() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: ringSetupSqpoll,
      );

  static TransportTcpClientConfiguration tcpClient() => TransportTcpClientConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
        pool: 1,
      );

  static TransportUdpClientConfiguration udpClient() => TransportUdpClientConfiguration(
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );

  static TransportUnixStreamClientConfiguration unixStreamClient() => TransportUnixStreamClientConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
        pool: 1,
      );

  static TransportUnixDatagramClientConfiguration unixDatagramClient() => TransportUnixDatagramClientConfiguration(
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );

  static TransportTcpServerConfiguration tcpServer() => TransportTcpServerConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );

  static TransportUdpServerConfiguration udpServer() => TransportUdpServerConfiguration(
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );

  static TransportUnixStreamServerConfiguration unixStreamServer() => TransportUnixStreamServerConfiguration(
        maxConnections: 4096,
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );

  static TransportUnixDatagramServerConfiguration unixDatagramServer() => TransportUnixDatagramServerConfiguration(
        receiveBufferSize: 4 * 1024 * 1024,
        sendBufferSize: 4 * 1024 * 1024,
      );
}
