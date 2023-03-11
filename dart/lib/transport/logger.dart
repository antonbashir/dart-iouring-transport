import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'constants.dart';

class TransportLogger {
  final TransportLogLevel level;
  late final RawReceivePort nativePort;

  TransportLogger(this.level);

  int listenNative() {
    nativePort = RawReceivePort((event) {
      Pointer<transport_logging_event_t> pointer = Pointer.fromAddress(event);
      log(TransportLogLevel.values[pointer.ref.level], pointer.ref.message.cast<Utf8>().toDartString());
      malloc.free(pointer.ref.message);
      malloc.free(pointer);
    });
    return nativePort.sendPort.nativePort;
  }

  void log(TransportLogLevel level, String message) {
    if (level.index < this.level.index) return;

    if (level.index > TransportLogLevel.Warn.index) {
      stderr.writeln("${TransportLogLevels[level.index]} ${DateTime.now()} $message");
      stderr.flush();
      return;
    }

    stdout.writeln("${TransportLogLevels[level.index]} ${DateTime.now()} $message");
    stdout.flush();
  }

  void trace(String message) => log(TransportLogLevel.Trace, message);
  void debug(String message) => log(TransportLogLevel.Debug, message);
  void info(String message) => log(TransportLogLevel.Info, message);
  void warn(String message) => log(TransportLogLevel.Warn, message);
  void error(String message) => log(TransportLogLevel.Error, message);
  void fatal(String message) => log(TransportLogLevel.Fatal, message);
}
