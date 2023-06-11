import 'package:meta/meta.dart';

import '../constants.dart';
import 'file.dart';

class TransportFileRegistry {
  final _files = <int, TransportFileChannel>{};

  TransportFileRegistry();

  @pragma(preferInlinePragma)
  TransportFileChannel? get(int fd) => _files[fd];

  @pragma(preferInlinePragma)
  void remove(int fd) => _files.remove(fd);

  @pragma(preferInlinePragma)
  void add(int fd, TransportFileChannel file) => _files[fd] = file;

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_files.values.toList().map((file) => file.close(gracefulDuration: gracefulDuration)));

  @visibleForTesting
  Map<int, TransportFileChannel> get files => _files;
}
