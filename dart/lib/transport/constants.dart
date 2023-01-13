const preferInlinePragma = "vm:prefer-inline";

const empty = "";
const newLine = "\n";
const slash = "/";
const dot = ".";
const star = "*";
const equalSpaced = " = ";
const openingBracket = "{";
const closingBracket = "}";
const comma = ",";
const parentDirectorySymbol = '..';
const currentDirectorySymbol = './';

const transportLibraryName = "libtransport.so";
const transportPackageName = "iouring_transport";

const int32Max = 4294967295;
const batchInitiaSize = 512;
const awaitStateDuration = Duration(seconds: 1);
const awaitTransactionDuration = Duration(milliseconds: 1);

const packageConfigJsonFile = "package_config.json";

String loadError(path) => "Unable to load library ${path}";

const unableToFindProjectRoot = "Unable to find project root";

const dlCloseFunction = 'dlclose';

const pubspecYamlFile = 'pubspec.yaml';
const pubspecYmlFile = 'pubspec.yml';


class Directories {
  const Directories._();

  static const native = "/native";
  static const package = "/package";
  static const dotDartTool = ".dart_tool";
}

class Messages {
  const Messages._();

  static const runPubGet = "Run 'dart pub get'";
  static const specifyDartEntryPoint = 'Specify dart execution entry point';
  static const projectRootNotFound = "Project root not found (parent of 'pubspec.yaml')";
  static const nativeSourcesNotFound = "Native root does not contain any *.c or *.cpp sources";
}

class FileExtensions {
  const FileExtensions._();

  static const exe = "exe";
  static const so = "so";
  static const h = "h";
  static const c = "c";
  static const cpp = "cpp";
  static const hpp = "hpp";
  static const tarGz = "tar.gz";
}

class CompileOptions {
  const CompileOptions._();

  static const dartExecutable = "dart";
  static const tarExecutable = "tar";
  static const tarOption = "-czf";
  static const compileCommand = "compile";
  static const outputOption = "-o";
  static const gccExecutable = "gcc";
  static const gccSharedOption = "-shared";
  static const gccFpicOption = "-fPIC";
}

class PackageConfigFields {
  PackageConfigFields._();

  static const rootUri = 'rootUri';
  static const name = 'name';
  static const packages = 'packages';
}
