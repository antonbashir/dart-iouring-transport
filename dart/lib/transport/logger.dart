import 'constants.dart';

class TransportLogger {
  final TransportLogLevel level;

  TransportLogger(this.level);

  @pragma(preferInlinePragma)
  void _log(TransportLogLevel level, String message) {
    if (level.index < this.level.index) return;
    print("${transportLogLevels[level.index]} ${DateTime.now()} $message");
  }

  void trace(String message) => _log(TransportLogLevel.trace, message);
  void debug(String message) => _log(TransportLogLevel.debug, message);
  void info(String message) => _log(TransportLogLevel.info, message);
  void warn(String message) => _log(TransportLogLevel.warn, message);
  void error(String message) => _log(TransportLogLevel.error, message);
  void fatal(String message) => _log(TransportLogLevel.fatal, message);
}
