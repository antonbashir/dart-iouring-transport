import 'package:meta/meta.dart';

import '../constants.dart';
import 'client.dart';

class TransportClientRegistry {
  final _clients = <int, TransportClientChannel>{};

  TransportClientRegistry();

  @pragma(preferInlinePragma)
  TransportClientChannel? get(int fd) => _clients[fd];

  @pragma(preferInlinePragma)
  void remove(int fd) => _clients.remove(fd);

  @pragma(preferInlinePragma)
  void add(int fd, TransportClientChannel channel) => _clients[fd] = channel;

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulTimeout}) => Future.wait(_clients.values.toList().map((client) => client.close(gracefulTimeout: gracefulTimeout)));

  @visibleForTesting
  Map<int, TransportClientChannel> get clients => _clients;
}
