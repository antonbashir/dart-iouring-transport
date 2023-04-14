import 'configuration.dart';
import 'constants.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
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
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        pool: 1,
        connectTimeout: Duration(seconds: 10),
        readTimeout: Duration(seconds: 10),
        writeTimeout: Duration(seconds: 10),
      );

  static TransportUdpClientConfiguration udpClient() => TransportUdpClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(seconds: 10),
        writeTimeout: Duration(seconds: 10),
      );

  static TransportUnixStreamClientConfiguration unixStreamClient() => TransportUnixStreamClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        pool: 1,
        connectTimeout: Duration(seconds: 10),
        readTimeout: Duration(seconds: 10),
        writeTimeout: Duration(seconds: 10),
      );

  static TransportUnixDatagramClientConfiguration unixDatagramClient() => TransportUnixDatagramClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(seconds: 10),
        writeTimeout: Duration(seconds: 10),
      );

  static TransportTcpServerConfiguration tcpServer() => TransportTcpServerConfiguration(
        socketMaxConnections: 4096,
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketReusePort: true,
      );

  static TransportUdpServerConfiguration udpServer() => TransportUdpServerConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketReusePort: true,
      );

  static TransportUnixStreamServerConfiguration unixStreamServer() => TransportUnixStreamServerConfiguration(
        socketMaxConnections: 4096,
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketReusePort: true,
      );

  static TransportUnixDatagramServerConfiguration unixDatagramServer() => TransportUnixDatagramServerConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketReusePort: true,
      );
}
