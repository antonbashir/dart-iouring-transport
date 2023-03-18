import 'dart:isolate';

import 'constants.dart';

class TransportLogger {
  final TransportLogLevel level;
  late final RawReceivePort nativePort;

  TransportLogger(this.level);

  @pragma(preferInlinePragma)
  void log(TransportLogLevel level, String message) {
    if (level.index < this.level.index) return;
    print("${transportLogLevels[level.index]} ${DateTime.now()} $message");
  }

  void trace(String message) => log(TransportLogLevel.trace, message);
  void debug(String message) => log(TransportLogLevel.debug, message);
  void info(String message) => log(TransportLogLevel.info, message);
  void warn(String message) => log(TransportLogLevel.warn, message);
  void error(String message) => log(TransportLogLevel.error, message);
  void fatal(String message) => log(TransportLogLevel.fatal, message);
}
