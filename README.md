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
    - [\[async\] shutdown()](#async-shutdown)
    - [\[async\] worker()](#async-worker)
- [TransportWorker](#transportworker)
  - [Properties](#properties)
    - [active](#active)
    - [id](#id)
    - [descriptor](#descriptor)
    - [servers](#servers)
    - [clients](#clients)
    - [files](#files)
  - [Methods](#methods)
    - [\[async\] initialize()](#async-initialize)
- [TransportClientConnection](#transportclientconnection)
  - [Properties](#properties-1)
    - [active](#active-1)
    - [inbound](#inbound)
  - [Methods](#methods-1)
    - [\[async\] read()](#async-read)
    - [stream()](#stream)
    - [writeSingle()](#writesingle)
    - [writeMany()](#writemany)
    - [\[async\] close()](#async-close)
- [TransportServerConnection](#transportserverconnection)
  - [Properties](#properties-2)
    - [active](#active-2)
    - [inbound](#inbound-1)
  - [Methods](#methods-2)
    - [\[async\] read()](#async-read-1)
    - [stream()](#stream-1)
    - [writeSingle()](#writesingle-1)
    - [writeMany()](#writemany-1)
    - [\[async\] close()](#async-close-1)
    - [\[async\] closeServer()](#async-closeserver)
- [TransportServerDatagramReceiver](#transportserverdatagramreceiver)
  - [Properties](#properties-3)
    - [active](#active-3)
    - [inbound](#inbound-2)
  - [Methods](#methods-3)
    - [receive()](#receive)
    - [\[async\] close()](#async-close-2)
- [TransportServerDatagramResponder](#transportserverdatagramresponder)
  - [Properties](#properties-4)
    - [active](#active-4)
    - [receivedBytes](#receivedbytes)
  - [Methods](#methods-4)
    - [respond()](#respond)
    - [release() - Releases the buffer used by the datagram responder.](#release---releases-the-buffer-used-by-the-datagram-responder)
    - [takeBytes()](#takebytes)
    - [toBytes()](#tobytes)
- [TransportDatagramClient](#transportdatagramclient)
  - [Properties](#properties-5)
    - [active](#active-5)
    - [inbound](#inbound-3)
  - [Methods](#methods-5)
    - [\[async\] receive()](#async-receive)
    - [stream()](#stream-2)
    - [send()](#send)
    - [\[async\] close()](#async-close-3)
- [TransportFile](#transportfile)
  - [Properties](#properties-6)
    - [inbound](#inbound-4)
    - [active](#active-6)
  - [Methods](#methods-6)
    - [read()](#read)
    - [writeSingle()](#writesingle-2)
    - [writeMany()](#writemany-2)
    - [\[async\] load()](#async-load)
    - [\[async\] close()](#async-close-4)
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

A simple example can be found [here](https://github.com/antonbashir/dart-iouring-sample).

# API

# Transport

### [async] shutdown()
* [optional] `Duration gracefulDuration` - The duration to wait before closing.
* [return] `Future<void>` - A future that completes when the operation finishes.

### [async] worker()
* `TransportWorkerConfiguration configuration` - Worker configuration (refer to `TransportDefaults`).
* [return] `SendPort` - The port to be used in the `TransportWorker` constructor. `SendPort` is used to facilitate worker usage with isolates.

# TransportWorker

## Properties
### active 
* [return] `bool` - Returns true if the worker is active; otherwise, it returns false.

### id 
* [return] `int` - The ID of the worker.

### descriptor 
* [return] `int` - The file descriptor of the worker's ring.

### servers 
* [return] `TransportServersFactory` - The server factory of the worker.

### clients 
* [return] `TransportClientsFactory` - The client factory of the worker.

### files 
* [return] `TransportFilesFactory` - The file factory of the worker.

## Methods
### [async] initialize()
* [return] `Future<void>` - A future that completes when the initialization is finished.

# TransportClientConnection

## Properties
### active 
* [return] `bool` - Returns true if the client connection is active; otherwise, it returns false.

### inbound 
* [return] `Stream<TransportPayload>` - The inbound stream of the client.

## Methods
### [async] read()
* [return] `Future<void>` - A future that completes when the reading process is finished.

### stream()
* [return] `Stream<TransportPayload>` - A stream that provides data as it becomes available.

### writeSingle()
* `Uint8List bytes` - The data to be written.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany()
* `List<Uint8List> bytes` - The list of data to be written.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional]`void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] close()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the connection.
* [return] `Future<void>` - A future that completes when the connection is closed.

# TransportServerConnection

## Properties
### active 
* [return]

 `bool` - Returns true if the server connection is active; otherwise, it returns false.

### inbound 
* [return] `Stream<TransportPayload>` - The inbound stream of the server.

## Methods
### [async] read()
* [return] `Future<void>` - A future that completes when the reading process is finished.

### stream()
* [return] `Stream<TransportPayload>` - A stream that provides data as it becomes available.

### writeSingle()
* `Uint8List bytes` - The data to be written.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany()
* `List<Uint8List> bytes` - The list of data to be written.
* [optional]`void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] close()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the connection.
* [return] `Future<void>` - A future that completes when the connection is closed.

### [async] closeServer()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the server.
* [return] `Future<void>` - A future that completes when the server is closed.

# TransportServerDatagramReceiver

## Properties
### active 
* [return] `bool` - Returns true if the server datagram receiver is active; otherwise, it returns false.

### inbound 
* [return] `Stream<TransportServerDatagramResponder>` - The inbound stream of the server datagram receiver.

## Methods
### receive()
* [optional] `int flags` - Optional flags to control the behavior of the receive method.
* [return] `Stream<TransportServerDatagramResponder>` - A stream that provides data as it becomes available.

### [async] close()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the server datagram receiver.
* [return] `Future<void>` - A future that completes when the server datagram receiver is closed.

# TransportServerDatagramResponder

## Properties
### active 
* [return] `bool` - Returns true if the datagram responder is active; otherwise, it returns false.

### receivedBytes 
* [return] `Uint8List` - The bytes received by the datagram responder.

## Methods
### respond()
* `Uint8List bytes` - The bytes to be sent as a response.
* [optional] `int flags` - Optional flags to control the behavior of the respond method.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when the response is finished.

### release() - Releases the buffer used by the datagram responder.

### takeBytes()
* [optional] `bool release` - If true (default), the buffer is released after taking the bytes.
* [return] `Uint8List` - The bytes received by the responder.

### toBytes()
* [optional] `bool release` - If true (default), the buffer is released after converting the bytes to a list.
* [return] `List<int>` - A list of bytes received by the responder.

# TransportDatagramClient

## Properties
### active 
* [return] `bool` - Returns true

 if the datagram client is active; otherwise, it returns false.

### inbound 
* [return] `Stream<TransportPayload>` - The inbound stream of the client.

## Methods
### [async] receive()
* [optional] `int flags` - Optional flags to control the behavior of the receive method.
* [return] `Future<void>` - A future that completes when the process of receiving datagrams is finished.

### stream()
* [optional] `int flags` - Optional flags to control the behavior of the stream method.
* [return] `Stream<TransportPayload>` - A stream that provides data as it becomes available.

### send()
* `Uint8List bytes` - The bytes to be sent.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `int flags` - Optional flags to control the behavior of the send method.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when sending is finished.

### [async] close()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the client.
* [return] `Future<void>` - A future that completes when the client is closed.

# TransportFile

## Properties
### inbound 
* [return] `Stream<TransportPayload>` - The inbound stream of the file.

### active 
* [return] `bool` - Returns true if the file is active; otherwise, it returns false.

## Methods
### read()
* [optional] `int blocksCount` - The number of blocks to read. Defaults to 1.
* [optional] `int offset` - The offset from the start of the file to begin reading. Defaults to 0.

### writeSingle()
* `Uint8List bytes` - The bytes to write.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### writeMany()
* `List<Uint8List> bytes` - The list of byte blocks to write.
* [optional] `TransportRetryConfiguration retry` - Optional retry configuration.
* [optional] `void Function(Exception error) onError` - Optional callback for error handling.
* [optional] `void Function() onDone` - Optional callback to be called when writing is finished.

### [async] load()
* [optional] `int blocksCount` - The number of blocks to read at once. Defaults to 1.
* [optional] `int offset` - The offset from the start of the file to begin reading. Defaults to 0.
* [return] `Future<Uint8List>` - A future that completes with the content of the file.

### [async] close()
* [optional] `Duration gracefulDuration` - Optional duration to wait before force closing the file.
* [return] `Future<void>` - A future that completes when the file is closed.

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
4. Reactive transport
5. Media transport
6. SSL

# Contribution

Currently maintainer hasn't resources on maintain pull requests but issues are welcome.

Every issue will be observed, discussed and applied or closed if this project does not need it.
