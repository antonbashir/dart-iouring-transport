# Introduction

<img src="dart-logo.png"  height="80" />

The main goal of this library is to provide fast transport API to Dart developers.

- [Introduction](#introduction)
  - [Features](#features)
- [Installation \& Usage](#installation--usage)
    - [Quick start](#quick-start)
  - [Sample](#sample)
- [API](#api)
- [Transport](#transport)
    - [\[async\] shutdown() - Shutdowning all workers](#async-shutdown---shutdowning-all-workers)
    - [\[async\] worker() - Shutdowning all workers](#async-worker---shutdowning-all-workers)
- [TransportWorker](#transportworker)
- [TransportClientConnection](#transportclientconnection)
- [TransportServerConnection](#transportserverconnection)
- [TransportServerDatagramReceiver](#transportserverdatagramreceiver)
- [TransportServerDatagramResponder](#transportserverdatagramresponder)
- [TransportDatagramClient](#transportdatagramclient)
- [TransportFile](#transportfile)
- [Perfomance](#perfomance)
- [Limitations](#limitations)
- [Further work](#further-work)
- [Contribution](#contribution)

## Features
- TCP
- UDP
- UNIX socket streams
- UNIX socket datagrams
- files
- fast
- asynchronous (based on Dart streams and futures)

# Installation & Usage

### Quick start

1. Create Dart project with pubspec.yaml
2. Add this section to dependencies:

```
  iouring_transport:
    git: 
      url: https://github.com/antonbashir/dart-iouring-transport/
      path: dart
```

3. Run `dart pub get`
4. Look at the [API](#api) and Enjoy!

## Sample

You can find simple example [here](https://github.com/antonbashir/dart-iouring-sample)

# API

# Transport

### [async] shutdown() - Shutdowning all workers
* [optional] `Duration gracefulDuration` - How long to wait before closing

### [async] worker() - Shutdowning all workers
* `TransportWorkerConfiguration configuration` - Worker configuration (see `TransportDefaults`)
* [return] `SendPort` - This port you should put into `TransportWorker` constructor. I use `SendPort` to make available of using workers with isolates.

# TransportWorker

# TransportClientConnection

# TransportServerConnection

# TransportServerDatagramReceiver

# TransportServerDatagramResponder

# TransportDatagramClient

# TransportFile

# Perfomance

TODO: Make benchmark on preferable machine

Latest benchmark results:

- RPS: 100k-150k per isolate for echo (server and client in same process, different isolates)

# Limitations

- Linux only
- Not production tested, current version is coded and tested by function unit tests, bugs are possible

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
