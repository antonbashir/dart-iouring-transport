import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/bindings.dart';

import 'constants.dart';

extension IntExtension on int {
  String transportEventToString() {
    if (this & transportEventRead != 0) return "[Read]";
    if (this & transportEventWrite != 0) return "[Write]";
    if (this & transportEventAccept != 0) return "[Accept]";
    if (this & transportEventConnect != 0) return "[Connect]";
    if (this & transportEventReadCallback != 0) return "[ReadCallback]";
    if (this & transportEventWriteCallback != 0) return "[WriteCallback]";
    return "unkown";
  }

  String kernelErrorToString(TransportBindings bindings) => bindings.strerror(-this).cast<Utf8>().toDartString();
}
