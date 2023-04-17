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
        timeoutCheckerPeriod: Duration(milliseconds: 500),
      );

  static TransportWorkerConfiguration outbound() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 16384,
        ringFlags: ringSetupSqpoll,
        timeoutCheckerPeriod: Duration(milliseconds: 500),
      );

  static TransportTcpClientConfiguration tcpClient() => TransportTcpClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        pool: 1,
        connectTimeout: Duration(seconds: 60),
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
      );

  static TransportUdpClientConfiguration udpClient() => TransportUdpClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
      );

  static TransportUnixStreamClientConfiguration unixStreamClient() => TransportUnixStreamClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        pool: 1,
        connectTimeout: Duration(seconds: 60),
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
        socketNonblock: true,
        socketClockexec: true,
      );

  static TransportUnixDatagramClientConfiguration unixDatagramClient() => TransportUnixDatagramClientConfiguration(
        socketReceiveBufferSize: 64 * 1024,
        socketSendBufferSize: 64 * 1024,
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
        socketNonblock: true,
        socketClockexec: true,
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
        socketNonblock: true,
        socketClockexec: true,
      );

  static TransportUnixDatagramServerConfiguration unixDatagramServer() => TransportUnixDatagramServerConfiguration(
        socketReceiveBufferSize: 64 * 1024,
        socketSendBufferSize: 64 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketNonblock: true,
        socketClockexec: true,
      );
}
