import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/bindings.dart';

import 'constants.dart';

extension IntExtension on int {
  String transportEventToString() {
    if (this & transportEventClose != 0) return "transportEventClose";
    if (this & transportEventRead != 0) return "transportEventRead";
    if (this & transportEventWrite != 0) return "transportEventWrite";
    if (this & transportEventAccept != 0) return "transportEventAccept";
    if (this & transportEventConnect != 0) return "transportEventConnect";
    if (this & transportEventReadCallback != 0) return "transportEventReadCallback";
    if (this & transportEventWriteCallback != 0) return "transportEventWriteCallback";
    return "unkown";
  }

  String kernelErrorToString(TransportBindings bindings) => bindings.strerror(-this).cast<Utf8>().toDartString();
}
