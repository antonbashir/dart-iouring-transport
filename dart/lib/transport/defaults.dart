import 'client/configuration.dart';
import 'exception.dart';
import 'configuration.dart';
import 'constants.dart';
import 'server/configuration.dart';

class TransportDefaults {
  TransportDefaults._();

  static TransportWorkerConfiguration worker() => TransportWorkerConfiguration(
        trace: false,
        buffersCount: 4096,
        bufferSize: 4096,
        ringSize: 4096,
        ringFlags: 0,
        timeoutCheckerPeriod: Duration(milliseconds: 500),
        baseDelay: Duration(microseconds: 10),
        maxDelay: Duration(seconds: 5),
        delayRandomizationFactor: 0.25,
        cqePeekCount: 1024,
        cqeWaitCount: 1,
        cqeWaitTimeout: Duration(milliseconds: 1),
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
        baseDelay: Duration(milliseconds: 50),
        randomizationFactor: 0.25,
        maxDelay: Duration(seconds: 30),
        maxAttempts: 5,
        predicate: (exception) {
          if (exception is TransportZeroDataException) return true;
          if (exception is TransportCanceledException) return true;
          if (exception is TransportInternalException) return transportRetryableErrorCodes.contains(-exception.code);
          return false;
        },
      );
}
