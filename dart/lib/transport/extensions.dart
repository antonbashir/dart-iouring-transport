import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/constants.dart';

import 'bindings.dart';
import 'configuration.dart';

extension IntExtension on int {
  String kernelErrorToString(TransportBindings bindings) => bindings.strerror(-this).cast<Utf8>().toDartString();

  @pragma(preferInlinePragma)
  bool isReadEvent() => this == transportEventRead || this == transportEventReceiveMessage;

  @pragma(preferInlinePragma)
  bool isWriteEvent() => this == transportEventWrite || this == transportEventSendMessage;
}

extension TransportUdpMulticastConfigurationExtension on TransportUdpMulticastConfiguration {
  int getMembershipIndex(TransportBindings bindings) => using(
        (arena) => calculateInterfaceIndex ? bindings.transport_socket_get_interface_index(localInterface!.toNativeUtf8(allocator: arena).cast()) : interfaceIndex!,
      );
}
