import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/listener.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/loop.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'lookup.dart';

class Transport {
  final listenerExit = ReceivePort();
  final loopExit = ReceivePort();

  late final int isolatesCount;
  late final TransportEventLoop loop;
  late final TransportConfiguration _transportConfiguration;
  late final TransportAcceptorConfiguration _acceptorConfiguration;
  late final TransportChannelConfiguration _channelConfiguration;
  late final String? _libraryPath;
  late final TransportLogger _logger;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transport;

  Transport({String? libraryPath}) {
    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);
    this._libraryPath = libraryPath;
  }

  void initialize(
    TransportConfiguration transportConfiguration,
    TransportAcceptorConfiguration acceptorConfiguration,
    TransportChannelConfiguration channelConfiguration,
  ) {
    _transportConfiguration = transportConfiguration;
    _acceptorConfiguration = acceptorConfiguration;
    _channelConfiguration = channelConfiguration;

    _logger = TransportLogger(transportConfiguration.logLevel);

    final nativeTransportConfiguration = calloc<transport_configuration_t>();
    nativeTransportConfiguration.ref.logging_port = _logger.listenNative();

    final nativeAcceptorConfiguration = calloc<transport_acceptor_configuration_t>();
    nativeAcceptorConfiguration.ref.max_connections = acceptorConfiguration.maxConnections;
    nativeAcceptorConfiguration.ref.receive_buffer_size = acceptorConfiguration.receiveBufferSize;
    nativeAcceptorConfiguration.ref.send_buffer_size = acceptorConfiguration.sendBufferSize;
    nativeAcceptorConfiguration.ref.ring_flags = acceptorConfiguration.ringFlags;
    nativeAcceptorConfiguration.ref.ring_size = acceptorConfiguration.ringSize;

    final nativeChannelConfiguration = calloc<transport_channel_configuration_t>();
    nativeChannelConfiguration.ref.buffers_count = channelConfiguration.buffersCount;
    nativeChannelConfiguration.ref.buffer_size = channelConfiguration.bufferSize;
    nativeChannelConfiguration.ref.ring_flags = channelConfiguration.ringFlags;
    nativeChannelConfiguration.ref.ring_size = channelConfiguration.ringSize;

    _transport = _bindings.transport_initialize(
      nativeTransportConfiguration,
      nativeChannelConfiguration,
      nativeAcceptorConfiguration,
    );
  }

  Future<void> shutdown() async {
    _bindings.transport_shutdown(_transport);
    await listenerExit.take(isolatesCount * 2).toList();
    if (loop.serving) await loopExit.first;
    _bindings.transport_destroy(_transport);
  }

  Future<TransportEventLoop> listen({int isolates = 1}) async {
    isolatesCount = isolates;

    final fromIncoming = ReceivePort();
    final fromOutgoing = ReceivePort();
    final completer = StreamController();

    loop = TransportEventLoop(_libraryPath, _bindings, _transport, loopExit.sendPort);

    for (var isolate = 0; isolate < isolates; isolate++) {
      Isolate.spawn<SendPort>((toTransport) => TransportIncomingListener(toTransport).listen(), fromIncoming.sendPort, onExit: listenerExit.sendPort);
      Isolate.spawn<SendPort>((toTransport) => TransportOutgoingListener(toTransport).listen(), fromOutgoing.sendPort, onExit: listenerExit.sendPort);
    }

    fromIncoming.listen((port) {
      SendPort toIncoming = port as SendPort;
      toIncoming.send([_libraryPath, _transport.address, _channelConfiguration.ringSize, loop.onIncoming.sendPort]);
      completer.add(null);
    });

    fromOutgoing.listen((port) {
      SendPort toOutgoing = port as SendPort;
      toOutgoing.send([_libraryPath, _transport.address, _channelConfiguration.ringSize, loop.onOutgoing.sendPort]);
      completer.add(null);
    });

    return completer.stream.take(isolates * 2).toList().then((value) {
      fromIncoming.close();
      fromOutgoing.close();
      completer.close();
      return loop;
    });
  }
}
