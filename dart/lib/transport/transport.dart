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

  late final String? _libraryPath;
  late final TransportEventLoop _loop;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transport;

  Transport(this.transportConfiguration, this.acceptorConfiguration, this.channelConfiguration, this.connectorConfiguration, {String? libraryPath}) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

    logger = TransportLogger(transportConfiguration.logLevel);

    final nativeTransportConfiguration = calloc<transport_configuration_t>();

    final nativeAcceptorConfiguration = calloc<transport_acceptor_configuration_t>();
    nativeAcceptorConfiguration.ref.max_connections = acceptorConfiguration.maxConnections;
    nativeAcceptorConfiguration.ref.receive_buffer_size = acceptorConfiguration.receiveBufferSize;
    nativeAcceptorConfiguration.ref.send_buffer_size = acceptorConfiguration.sendBufferSize;

    final nativeConnectorConfiguration = calloc<transport_connector_configuration_t>();
    nativeConnectorConfiguration.ref.max_connections = connectorConfiguration.maxConnections;
    nativeConnectorConfiguration.ref.receive_buffer_size = connectorConfiguration.receiveBufferSize;
    nativeConnectorConfiguration.ref.send_buffer_size = connectorConfiguration.sendBufferSize;

    final nativeChannelConfiguration = calloc<transport_channel_configuration_t>();
    nativeChannelConfiguration.ref.buffers_count = channelConfiguration.buffersCount;
    nativeChannelConfiguration.ref.buffer_size = channelConfiguration.bufferSize;
    nativeChannelConfiguration.ref.ring_flags = channelConfiguration.ringFlags;
    nativeChannelConfiguration.ref.ring_size = channelConfiguration.ringSize;

    _transport = _bindings.transport_initialize(
      nativeTransportConfiguration,
      nativeChannelConfiguration,
      nativeConnectorConfiguration,
      nativeAcceptorConfiguration,
    );
    logger.info("[ransport]: initialized");
  }

  Future<void> shutdown() async {
    await _listenerExit.take(transportConfiguration.isolates).toList();
    if (_loop.serving) await _loopExit.first;
    _bindings.transport_destroy(_transport);
    logger.info("[transport]: destroyed");
  }

  Future<TransportEventLoop> run() async {
    final fromListener = ReceivePort();
    final fromListenerActivator = ReceivePort();
    final completer = Completer();
    var completionCounter = 0;
    _loop = TransportEventLoop(_bindings, _transport, this, _loopExit.sendPort, (listener) {
      for (var isolate = 0; isolate < transportConfiguration.isolates; isolate++) {
        Isolate.spawn<SendPort>(
          (toTransport) => TransportListener(toTransport).listen(),
          fromListener.sendPort,
          onExit: _listenerExit.sendPort,
        );
      }

      fromListener.listen((port) {
        SendPort toListener = port as SendPort;
        toListener.send([
          _libraryPath,
          _transport.address,
          channelConfiguration.ringSize,
          listener.sendPort,
          fromListenerActivator.sendPort,
        ]);
      });

      fromListenerActivator.listen((channel) {
        _bindings.transport_channel_pool_add(_transport.ref.channels, Pointer.fromAddress(channel));
        logger.info("[listener]: activated");
        if (++completionCounter == transportConfiguration.isolates) {
          completer.complete();
        }
      });
    });

    return completer.future.then((value) {
      fromListener.close();
      fromListenerActivator.close();
      return _loop;
    });
  }
}
