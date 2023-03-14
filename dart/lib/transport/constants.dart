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

enum TransportChannelPoolMode { RoundRobbin, LeastConnections }

enum TransportLogLevel {
  trace,
  debug,
  info,
  warn,
  error,
  fatal,
}

const transportLogLevels = [
  "TRACE",
  "DEBUG",
  "INFO",
  "WARN",
  "ERROR",
  "FATAL",
];

const transportBufferAvailable = -2;
const transportBufferUsed = -1;

const transportEventClose = 1 << (64 - 1 - 0);
const transportEventRead = 1 << (64 - 1 - 1);
const transportEventWrite = 1 << (64 - 1 - 2);
const transportEventAccept = 1 << (64 - 1 - 3);
const transportEventConnect = 1 << (64 - 1 - 4);
const transportEventReadCallback = 1 << (64 - 1 - 5);
const transportEventWriteCallback = 1 << (64 - 1 - 6);
const transportEventAll = transportEventRead | transportEventWrite | transportEventAccept | transportEventConnect | transportEventClose | transportEventReadCallback | transportEventWriteCallback;

const ringSetupIopoll = 1 << 0;
const ringSetupSqpoll = 1 << 1;
const ringSetupSqAff = 1 << 2;
const ringSetupCqsize = 1 << 3;
const ringSetupClamp = 1 << 4;
const ringSetupAttachWq = 1 << 5;
const ringSetupRDisabled = 1 << 6;
const ringSetupSubmitAll = 1 << 7;
const ringSetupCoopTaskrun = 1 << 8;
const ringSetupTaskrunFlag = 1 << 9;
const ringSetupSqe128 = 1 << 10;
const ringSetupCqe32 = 1 << 11;
const ringSetupSingleIssuer = 1 << 12;
const ringSetupDeferTaskrun = 1 << 13;
