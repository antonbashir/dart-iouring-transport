import 'dart:ffi';
import 'dart:io';

import 'bindings.dart';
import 'lookup.dart';

class Transport {
  late TransportBindings _bindings;
  late TransportLibrary _library;

  Transport({String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
  }

  void test() => _bindings.test();
}
