# Introduction

<img src="dart-logo.png"  height="80" />

This library's primary objective is to deliver a high-speed transport API to Dart developers.
- [Introduction](#introduction)
  - [Features](#features)
- [Installation \& Usage](#installation--usage)
    - [Quick Start](#quick-start)
  - [Sample](#sample)
- [API](#api)
- [Transport](#transport)
    - [\[async\] shutdown() - Shuts down the transport layer. If `gracefulDuration` is provided, the system will wait for the specified duration before shutting down.](#async-shutdown---shuts-down-the-transport-layer-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-shutting-down)
    - [\[async\] worker() - Creates a worker based on the given configuration. Returns a `SendPort` to be used in the `TransportWorker` constructor.](#async-worker---creates-a-worker-based-on-the-given-configuration-returns-a-sendport-to-be-used-in-the-transportworker-constructor)
- [TransportWorker](#transportworker)
  - [Properties](#properties)
    - [active - Indicates whether the worker is currently active or not.](#active---indicates-whether-the-worker-is-currently-active-or-not)
    - [id - Returns the ID of the worker.](#id---returns-the-id-of-the-worker)
    - [descriptor - Returns the file descriptor of the worker's ring.](#descriptor---returns-the-file-descriptor-of-the-workers-ring)
    - [servers - Returns the server factory of the worker.](#servers---returns-the-server-factory-of-the-worker)
    - [clients - Returns the client factory of the worker.](#clients---returns-the-client-factory-of-the-worker)
    - [files - Returns the file factory of the worker.](#files---returns-the-file-factory-of-the-worker)
  - [Methods](#methods)
    - [\[async\] initialize() - Initializes the worker.](#async-initialize---initializes-the-worker)
- [TransportClientConnection](#transportclientconnection)
  - [Properties](#properties-1)
    - [active - Indicates whether the client connection is currently active or not.](#active---indicates-whether-the-client-connection-is-currently-active-or-not)
    - [inbound - Returns the inbound stream of the client.](#inbound---returns-the-inbound-stream-of-the-client)
  - [Methods](#methods-1)
    - [\[async\] read() - Initiates the reading process from the client.](#async-read---initiates-the-reading-process-from-the-client)
    - [stream() - Returns a stream of data as it becomes available.](#stream---returns-a-stream-of-data-as-it-becomes-available)
    - [writeSingle() - Writes a single chunk of data to the client.](#writesingle---writes-a-single-chunk-of-data-to-the-client)
    - [writeMany() - Writes multiple chunks of data to the client.](#writemany---writes-multiple-chunks-of-data-to-the-client)
    - [\[async\] close() - Closes the client connection. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the connection.](#async-close---closes-the-client-connection-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-connection)
- [TransportServerConnection](#transportserverconnection)
  - [Properties](#properties-2)
    - [active - Indicates whether the server connection is currently active or not.](#active---indicates-whether-the-server-connection-is-currently-active-or-not)
    - [inbound - Returns the inbound stream of the server.](#inbound---returns-the-inbound-stream-of-the-server)
  - [Methods](#methods-2)
    - [\[async\] read() - Initiates the reading process from the client connection.](#async-read---initiates-the-reading-process-from-the-client-connection)
    - [stream() - Returns a stream of data as it becomes available.](#stream---returns-a-stream-of-data-as-it-becomes-available-1)
    - [writeSingle() - Writes a single chunk of data to the client connection.](#writesingle---writes-a-single-chunk-of-data-to-the-client-connection)
    - [writeMany() - Writes multiple chunks of data to the client connection.](#writemany---writes-multiple-chunks-of-data-to-the-client-connection)
    - [\[async\] close() - Closes the server connection. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the connection.](#async-close---closes-the-server-connection-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-connection)
    - [\[async\] closeServer() - Closes the server. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the server.](#async-closeserver---closes-the-server-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-server)
- [TransportServerDatagramReceiver](#transportserverdatagramreceiver)
  - [Properties](#properties-3)
    - [active - Indicates whether the server datagram receiver is currently active or not.](#active---indicates-whether-the-server-datagram-receiver-is-currently-active-or-not)
    - [inbound - Returns the inbound stream of the server datagram receiver.](#inbound---returns-the-inbound-stream-of-the-server-datagram-receiver)
  - [Methods](#methods-3)
    - [receive() - Initiates the process of receiving datagrams.](#receive---initiates-the-process-of-receiving-datagrams)
    - [\[async\] close() - Closes the server datagram receiver. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the server datagram receiver.](#async-close---closes-the-server-datagram-receiver-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-server-datagram-receiver)
- [TransportServerDatagramResponder](#transportserverdatagramresponder)
  - [Properties](#properties-4)
    - [active - Indicates whether the datagram responder is currently active or not.](#active---indicates-whether-the-datagram-responder-is-currently-active-or-not)
    - [receivedBytes - Returns the bytes received by the datagram responder.](#receivedbytes---returns-the-bytes-received-by-the-datagram-responder)
  - [Methods](#methods-4)
    - [respond() - Sends a response with the given bytes.](#respond---sends-a-response-with-the-given-bytes)
    - [release() - Releases the buffer used by the datagram responder.](#release---releases-the-buffer-used-by-the-datagram-responder)
    - [takeBytes() - Retrieves and optionally releases the bytes received by the responder.](#takebytes---retrieves-and-optionally-releases-the-bytes-received-by-the-responder)
    - [toBytes() - Converts the received bytes to a list and optionally releases them.](#tobytes---converts-the-received-bytes-to-a-list-and-optionally-releases-them)
- [TransportDatagramClient](#transportdatagramclient)
  - [Properties](#properties-5)
    - [active - Indicates whether the datagram client is currently active or not.](#active---indicates-whether-the-datagram-client-is-currently-active-or-not)
    - [inbound - Returns the inbound stream of the client.](#inbound---returns-the-inbound-stream-of-the-client-1)
  - [Methods](#methods-5)
    - [\[async\] receive() - Initiates the process of receiving datagrams.](#async-receive---initiates-the-process-of-receiving-datagrams)
    - [stream() - Provides a stream of data as it becomes available.](#stream---provides-a-stream-of-data-as-it-becomes-available)
    - [send() - Sends the given bytes.](#send---sends-the-given-bytes)
    - [\[async\] close() - Closes the datagram client. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the client.](#async-close---closes-the-datagram-client-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-client)
- [TransportFile](#transportfile)
  - [Properties](#properties-6)
    - [inbound - Returns the inbound stream of the file.](#inbound---returns-the-inbound-stream-of-the-file)
    - [active - Indicates whether the file is currently active or not.](#active---indicates-whether-the-file-is-currently-active-or-not)
  - [Methods](#methods-6)
    - [read() - Reads a specified number of blocks from the file, starting at the given offset.](#read---reads-a-specified-number-of-blocks-from-the-file-starting-at-the-given-offset)
    - [writeSingle() - Writes the given bytes to the file.](#writesingle---writes-the-given-bytes-to-the-file)
    - [writeMany() - Writes multiple chunks of data to the file.](#writemany---writes-multiple-chunks-of-data-to-the-file)
    - [\[async\] load() - Reads a specified number of blocks from the file and returns them as a `Uint8List`.](#async-load---reads-a-specified-number-of-blocks-from-the-file-and-returns-them-as-a-uint8list)
    - [\[async\] close() - Closes the file. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the file.](#async-close---closes-the-file-if-gracefulduration-is-provided-the-system-will-wait-for-the-specified-duration-before-force-closing-the-file)
- [Performance](#performance)
- [Limitations](#limitations)
- [Further work](#further-work)
- [Contribution](#contribution)


## Features
- TCP
- UDP
- UNIX socket streams
- UNIX socket datagrams
- File management
- High-speed operations
- Asynchronous execution (leveraging Dart streams and futures)

# Installation & Usage

### Quick Start

1. Initiate a Dart project with pubspec.yaml.
2. Append the following section to your dependencies:

```
  iouring_transport:
    git: 
      url: https://github.com/antonbashir/dart-iouring-transport/
      path: dart
```

3. Run `dart pub get`.
4. Refer to the [API](#api) for implementation details. Enjoy!

## Sample

Simple example can be found [here](https://github.com/antonbashir/dart-iouring-sample).

Reactive transport implementation can be found [here](https://github.com/antonbashir/dart-reactive-transport).

# API

# Transport

### [async] shutdown() - Shuts down the transport layer. If `gracefulDuration` is provided, the system will wait for the specified duration before shutting down.
* [optional] `Duration gracefulDuration` - The duration to wait before closing.
* [return] `Future<void>` - A future that completes when the operation finishes.

### [async] worker() - Creates a worker based on the given configuration. Returns a `SendPort` to be used in the `TransportWorker` constructor.
* `TransportWorkerConfiguration configuration` - Worker configuration (refer to `TransportDefaults`).
* [return] `SendPort` - The port to be used in the `TransportWorker` constructor.

# TransportWorker

## Properties
### active - Indicates whether the worker is currently active or not.
* [return] `bool`

### id - Returns the ID of the worker.
* [return] `int`

### descriptor - Returns the file descriptor of the worker's ring.
* [return] `int`

### servers - Returns the server factory of the worker.
* [return] `TransportServersFactory`

### clients - Returns the client factory of the worker.
* [return] `TransportClientsFactory`

### files - Returns the file factory of the worker.
* [return] `TransportFilesFactory`

## Methods
### [async] initialize() - Initializes the worker.
* [return] `Future<void>`

# TransportClientConnection

## Properties
### active - Indicates whether the client connection is currently active or not.
* [return] `bool`

### inbound - Returns the inbound stream of the client.
* [return] `Stream<TransportPayload>`

## Methods
### [async] read() - Initiates the reading process from the client.
* [return] `Future<void>`

### stream() - Returns a stream of data as it becomes available.
* [return] `Stream<TransportPayload>`

### writeSingle() - Writes a single chunk of data to the client.
* `Uint8List bytes` - The data to be written.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany() - Writes multiple chunks of data to the client.
* `List<Uint8List> bytes` - The list of data to be written.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional]`void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] close() - Closes the client connection. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the connection.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the connection.
* [return] `Future<void>`

# TransportServerConnection

## Properties
### active - Indicates whether the server connection is currently active or not.
* [return] `bool`

### inbound - Returns the inbound stream of the server.
* [return] `Stream<TransportPayload>`

## Methods
### [async] read() - Initiates the reading process from the client connection.
* [return] `Future<void>`

### stream() - Returns a stream of data as it becomes available.
* [return] `Stream<TransportPayload>`

### writeSingle() - Writes a single chunk of data to the client connection.
* `Uint8List bytes`

 - The data to be written.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany() - Writes multiple chunks of data to the client connection.
* `List<Uint8List> bytes` - The list of data to be written.
* [optional]`void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] close() - Closes the server connection. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the connection.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the connection.
* [return] `Future<void>`

### [async] closeServer() - Closes the server. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the server.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the server.
* [return] `Future<void>`

# TransportServerDatagramReceiver

## Properties
### active - Indicates whether the server datagram receiver is currently active or not.
* [return] `bool`

### inbound - Returns the inbound stream of the server datagram receiver.
* [return] `Stream<TransportServerDatagramResponder>`

## Methods
### receive() - Initiates the process of receiving datagrams.
* [optional] `int flags` - Optional flags to control the behavior of the receive method.
* [return] `Stream<TransportServerDatagramResponder>`

### [async] close() - Closes the server datagram receiver. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the server datagram receiver.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the server datagram receiver.
* [return] `Future<void>`

# TransportServerDatagramResponder

## Properties
### active - Indicates whether the datagram responder is currently active or not.
* [return] `bool`

### receivedBytes - Returns the bytes received by the datagram responder.
* [return] `Uint8List`

## Methods
### respond() - Sends a response with the given bytes.
* `Uint8List bytes` - The bytes to be sent as a response.
* [optional] `int flags` - Optional flags to control the behavior of the respond method.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when the response is finished.

### release() - Releases the buffer used by the datagram responder.
* [return] `void`

### takeBytes() - Retrieves and optionally releases the bytes received by the responder.
* [optional] `bool release` - If true (default), the buffer is released after taking the bytes.
* [return] `Uint8List`

### toBytes() - Converts the received bytes to a list and optionally releases them.
* [optional] `bool release` - If true (default), the buffer is released after converting the bytes to a list.
* [return] `List<int>`

# TransportDatagramClient

## Properties
### active - Indicates whether the datagram client is currently active or not.
* [return] `bool`

### inbound - Returns the inbound stream of the client.
* [return] `Stream<TransportPayload>`

## Methods
### [async] receive() - Initiates the process of receiving datagrams.
* [optional] `int flags` - Optional flags to control the behavior of the receive method.
* [return] `Future<void>`

### stream() - Provides a stream of data as it becomes available.
* [optional] `int flags` - Optional flags to control the behavior of the stream method.
* [return] `Stream<TransportPayload>`

### send() - Sends the given bytes.
* `Uint8List bytes` - The bytes to be sent.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `int flags` - Optional flags to control the behavior of the send method.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when sending is finished.

### [async] close() - Closes the datagram client. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the client.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the client.
* [return] `Future<void>`

# TransportFile

## Properties
### inbound - Returns the inbound stream of the file.
* [return] `Stream<TransportPayload>`

### active - Indicates whether the file is currently active or not.
* [return] `bool`

## Methods
### read() - Reads a specified number of blocks from the file, starting at the given offset.
* [optional] `int blocksCount` - The number of blocks to read. Defaults to 1.
* [optional] `int offset` - The offset from the start of the file to begin reading. Defaults to 0.

### writeSingle() - Writes the given bytes to the file.
* `Uint8List bytes` - The bytes to write.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany() - Writes multiple chunks of data to the file.
* `List<Uint8List> bytes` - The list of byte blocks to write.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] load() - Reads a specified number of blocks from the file and returns them as a `Uint8List`.
* [optional] `int blocksCount` - The number of blocks to read at once. Defaults to 1.
* [optional] `int offset` - The offset from the start of the file to begin reading. Defaults to 0.
* [return] `Future<Uint8List>`

### [async] close() - Closes the file. If `gracefulDuration` is provided, the system will wait for the specified duration before force closing the file.
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the file.
* [return] `Future<void>`

# Performance

To be added: Benchmarking results on the preferred machine.

Most recent benchmark results:

- Requests per Second (RPS): 100k-150k per isolate for echo (server and client in the same process, different isolates)

# Limitations

- Only compatible with Linux.
- Not tested in a production environment. The current version is developed and tested with unit tests, so bugs may be present.

# Further work

1. Benchmarks and optimization
2. CI for building library and way to provide it to user modules (currently library included with sources, that is not good)
3. Demo project
4. Media transport
5. SSL

# Contribution

Currently maintainer hasn't resources on maintain pull requests but issues are welcome.

Every issue will be observed, discussed and applied or closed if this project does not need it.
