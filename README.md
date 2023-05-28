# Introduction

<img src="dart-logo.png"  height="80" />

The main goal of this library is to provide fast transport API to Dart developers.

- [Introduction](#introduction)
  - [Features](#features)
- [Installation \& Usage](#installation--usage)
    - [Quick start](#quick-start)
  - [Sample](#sample)
  - [Packaging](#packaging)
- [API](#api)
- [Perfomance](#perfomance)
- [Limitations](#limitations)
- [Further work](#further-work)
- [Contribution](#contribution)

## Features

- TCP
- UDP
- UNIX socket stream
- UNIX socket datagram
- file
- custom callbacks
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

## Packaging

If you want to distribute your module, run `dart run iouring_transport:pack ${path to main dart file}`.

This command will recompile Native files and create `${directory name}.tar.gz` archive with executables and libraries.

After this you can transfer archive to whatever place you want, unarchive it and run `module.exe`.

# API

TODO: write APIs

# Perfomance

TODO: Make benchmark on preferable machine

Latest benchmark results:

- RPS: 100k per isolate for echo (server and client in same process, different isolates)

# Limitations

- Linux only
- Linux kernel with support of IO_URING MSG type
- Not production tested, current version is coded and tested by function unit tests, bugs are possible

# Further work

1. Benchmarks and optimization
2. CI for building library and way to provide it to user modules (currently library included with sources, that is not good)
3. Demo project
4. Reactive transport
5. Media transport

# Contribution

Currently maintainer hasn't resources on maintain pull requests but issues are welcome.

Every issue will be observed, discussed and applied or closed if this project does not need it.
