import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'constants.dart';

extension IntExtension on int {
  String transportEventToString() {
    if (this == (transportEventRead | transportEventClient)) return "[ReadCallback]";
    if (this == (transportEventWrite | transportEventClient)) return "[WriteCallback]";
    if (this == transportEventRead) return "[Read]";
    if (this == transportEventWrite) return "[Write]";
    if (this == transportEventAccept) return "[Accept]";
    if (this == transportEventConnect) return "[Connect]";
    if (this == (transportEventSendMessage | transportEventClient)) return "[SendMessageCallback]";
    if (this == (transportEventReceiveMessage | transportEventClient)) return "[ReceiveMessageCallback]";
    if (this == transportEventSendMessage) return "[SendMessage]";
    if (this == transportEventReceiveMessage) return "[ReceiveMessage]";
    return "unkown";
  }

  String kernelErrorToString(TransportBindings bindings) => bindings.strerror(-this).cast<Utf8>().toDartString();
}
