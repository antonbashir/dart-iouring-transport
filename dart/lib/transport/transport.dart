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
  final TransportConfiguration transportConfiguration;
  final TransportAcceptorConfiguration acceptorConfiguration;
  final TransportChannelConfiguration channelConfiguration;
  final TransportConnectorConfiguration connectorConfiguration;
  late final TransportLogger logger;

  final _listenerExit = ReceivePort();
  final _loopExit = ReceivePort();

  late final TransportEventLoop _loop;
  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transport;

  Transport(this.transportConfiguration, this.acceptorConfiguration, this.channelConfiguration, this.connectorConfiguration, {String? libraryPath}) {
    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);
    this._libraryPath = libraryPath;

    logger = TransportLogger(transportConfiguration.logLevel);

    final nativeTransportConfiguration = calloc<transport_configuration_t>();
    nativeTransportConfiguration.ref.logging_port = logger.listenNative();

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
    await _listenerExit.take(transportConfiguration.inboundIsolates + transportConfiguration.outboundIsolates).toList();
    if (_loop.serving) await _loopExit.first;
    _bindings.transport_destroy(_transport);
  }

  Future<TransportEventLoop> run() async {
    final fromInbound = ReceivePort();
    final fromOutbound = ReceivePort();
    final fromInboundActivator = ReceivePort();
    final fromOutboundActivator = ReceivePort();
    final completer = Completer();
    var completionCounter = 0;
    _loop = TransportEventLoop(_libraryPath, _bindings, _transport, this, _loopExit.sendPort, (listener) {
      for (var isolate = 0; isolate < transportConfiguration.inboundIsolates; isolate++) {
        Isolate.spawn<SendPort>(
          (toTransport) => TransportListener(toTransport).listen(),
          fromInbound.sendPort,
          onExit: _listenerExit.sendPort,
        );
      }

      for (var isolate = 0; isolate < transportConfiguration.outboundIsolates; isolate++) {
        Isolate.spawn<SendPort>(
          (toTransport) => TransportListener(toTransport).listen(),
          fromOutbound.sendPort,
          onExit: _listenerExit.sendPort,
        );
      }

      fromInbound.listen((port) {
        SendPort toInbound = port as SendPort;
        toInbound.send([
          _libraryPath,
          _transport.address,
          channelConfiguration.ringSize,
          listener.sendPort,
          fromInboundActivator.sendPort,
        ]);
      });

      fromInboundActivator.listen((channel) {
        _bindings.transport_channel_pool_add(_transport.ref.inbound_channels, Pointer.fromAddress(channel));
        if (++completionCounter == transportConfiguration.inboundIsolates + transportConfiguration.outboundIsolates) {
          completer.complete();
        }
      });

      fromOutbound.listen((port) {
        SendPort toOutbound = port as SendPort;
        toOutbound.send([
          _libraryPath,
          _transport.address,
          channelConfiguration.ringSize,
          listener.sendPort,
          fromOutboundActivator.sendPort,
        ]);
      });

      fromOutboundActivator.listen((channel) {
        _bindings.transport_channel_pool_add(_transport.ref.outbound_channels, Pointer.fromAddress(channel));
        if (++completionCounter == transportConfiguration.inboundIsolates + transportConfiguration.outboundIsolates) {
          completer.complete();
        }
      });
    });

    return completer.future.then((value) {
      fromInbound.close();
      fromOutbound.close();
      fromInboundActivator.close();
      fromOutboundActivator.close();
      return _loop;
    });
  }
}
