import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'constants.dart';

extension IntExtension on int {
  String transportEventToString() {
    if (this == (transportEventRead | transportEventClient)) return "[client read]";
    if (this == (transportEventWrite | transportEventClient)) return "[client write]";
    if (this == (transportEventRead | transportEventFile)) return "[file read]";
    if (this == (transportEventWrite | transportEventFile)) return "[file write]";
    if (this == transportEventRead) return "[server read]";
    if (this == transportEventWrite) return "[server write]";
    if (this == transportEventAccept) return "[accept]";
    if (this == transportEventConnect) return "[connect]";
    if (this == (transportEventSendMessage | transportEventClient)) return "[client send message]";
    if (this == (transportEventReceiveMessage | transportEventClient)) return "[client receive message]";
    if (this == transportEventSendMessage) return "[server send message]";
    if (this == transportEventReceiveMessage) return "[server receive message]";
    return "[unkown]";
  }

  String kernelErrorToString(TransportBindings bindings) => bindings.strerror(-this).cast<Utf8>().toDartString();
}

extension TransportUdpMulticastConfigurationExtension on TransportUdpMulticastConfiguration {
  int getMembershipIndex(TransportBindings bindings) => using(
        (arena) => calculateInterfaceIndex ? bindings.transport_socket_get_interface_index(localInterface!.toNativeUtf8(allocator: arena).cast()) : interfaceIndex!,
      );
}
