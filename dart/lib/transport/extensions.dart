import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

extension TransportUdpMulticastConfigurationExtension on TransportUdpMulticastConfiguration {
  int getMembershipIndex(TransportBindings bindings) => using(
        (arena) {
          if (calculateInterfaceIndex) {
            return bindings.transport_socket_get_interface_index(localInterface!.toNativeUtf8(allocator: arena).cast());
          }
          return interfaceIndex!;
        },
      );
}
