library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  if (!File("test.txt").existsSync()) File("test.txt").createSync();
  File("test.txt").writeAsString("test");
  Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..file("test.txt").readString().then(print);
  // Transport(TransportDefaults.configuration(), TransportDefaults.loop())
  //   ..initialize()
  //   ..connection().bind("0.0.0.0", 1234).listen((serverChannel) async {
  //     serverChannel.bytesOutput.listen((event) => print("server:" + Utf8Decoder().convert(event)));
  //     while (true) {
  //       await Future.delayed(Duration(seconds: 1));
  //       serverChannel.queueReadString();
  //       serverChannel.queueWriteString("from server");
  //     }
  //   });
  // Transport(TransportDefaults.configuration(), TransportDefaults.loop())
  //   ..initialize()
  //   ..connection().connect("127.0.0.1", 1234).listen((clientChannel) async {
  //     clientChannel.bytesOutput.listen((event) => print("client:" + Utf8Decoder().convert(event)));
  //     while (true) {
  //       await Future.delayed(Duration(seconds: 1));
  //       clientChannel.queueReadString();
  //       clientChannel.queueWriteString("from client");
  //     }
  //   });
}
