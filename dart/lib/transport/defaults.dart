import 'client/configuration.dart';
import 'exception.dart';
import 'configuration.dart';
import 'constants.dart';
import 'server/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportConfiguration transport() => TransportConfiguration(
        listenerIsolates: 1,
        workerInsolates: 1,
      );

  static TransportListenerConfiguration listener() => TransportListenerConfiguration(
        ringSize: 8192,
        ringFlags: 0,
      );

  static TransportWorkerConfiguration inbound() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 8192,
        ringFlags: 0,
        timeoutCheckerPeriod: Duration(milliseconds: 500),
      );

  static TransportWorkerConfiguration outbound() => TransportWorkerConfiguration(
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 8192,
        ringFlags: 0,
        timeoutCheckerPeriod: Duration(milliseconds: 500),
      );

  static TransportTcpClientConfiguration tcpClient() => TransportTcpClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        pool: 1,
        connectTimeout: Duration(seconds: 60),
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
        socketNonblock: true,
        socketClockexec: true,
        tcpFastopen: true,
        tcpNoDelay: true,
        tcpQuickack: true,
        tcpDeferAccept: true,
      );

  static TransportUdpClientConfiguration udpClient() => TransportUdpClientConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(seconds: 60),
        writeTimeout: Duration(seconds: 60),
        socketNonblock: true,
        socketClockexec: true,
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
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
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
        socketNonblock: true,
        socketClockexec: true,
        tcpFastopen: true,
        tcpNoDelay: true,
        tcpQuickack: true,
        tcpDeferAccept: true,
      );

  static TransportUdpServerConfiguration udpServer() => TransportUdpServerConfiguration(
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketReusePort: true,
        socketNonblock: true,
        socketClockexec: true,
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
        socketReceiveBufferSize: 4 * 1024 * 1024,
        socketSendBufferSize: 4 * 1024 * 1024,
        readTimeout: Duration(days: 1),
        writeTimeout: Duration(days: 1),
        socketNonblock: true,
        socketClockexec: true,
      );

  static TransportRetryConfiguration retry() => TransportRetryConfiguration(
        delayFactor: Duration(milliseconds: 50),
        randomizationFactor: 0.25,
        maxDelay: Duration(seconds: 30),
        maxAttempts: 5,
        predicate: (exception) {
          if (exception is TransportZeroDataException) return true;
          if (exception is TransportInternalException && (transportRetryableErrorCodes.contains(-exception.code))) return true;
          return false;
        },
      );
}
