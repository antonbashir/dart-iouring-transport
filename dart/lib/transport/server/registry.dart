import 'package:meta/meta.dart';

import '../constants.dart';
import 'server.dart';

class TransportServerRegistry {
  final _servers = <int, TransportServerChannel>{};
  final _serverConnections = <int, TransportServerConnectionChannel>{};

  TransportServerRegistry();

  @pragma(preferInlinePragma)
  TransportServerChannel? getServer(int fd) => _servers[fd];

  @pragma(preferInlinePragma)
  TransportServerConnectionChannel? getConnection(int fd) => _serverConnections[fd];

  @pragma(preferInlinePragma)
  void addConnection(int connectionFd, TransportServerConnectionChannel connection) => _serverConnections[connectionFd] = connection;

  @pragma(preferInlinePragma)
  void removeConnection(int fd) => _serverConnections.remove(fd);

  @pragma(preferInlinePragma)
  void removeServer(int fd) => _servers.remove(fd);

  @pragma(preferInlinePragma)
  void addServer(int fd, TransportServerChannel channel) => _servers[fd] = channel;

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_servers.values.toList().map((server) => server.close(gracefulDuration: gracefulDuration)));

  @visibleForTesting
  Map<int, TransportServerChannel> get servers => _servers;

  @visibleForTesting
  Map<int, TransportServerConnectionChannel> get serverConnections => _serverConnections;
}
