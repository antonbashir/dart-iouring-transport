import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:test/test.dart';

final Transport _transport = Transport(
  TransportDefaults.transport(),
  TransportDefaults.acceptor(),
  TransportDefaults.channel(),
  TransportDefaults.connector(),
);

void main() {
  int value = 2523623;

  int flag1 = 1 << 63;
  int flag2 = 1 << 62;

  int valueWithFlags = value | flag1 | flag2;
}
