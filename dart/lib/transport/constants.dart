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

const transportEventRead = 1 << 0;
const transportEventWrite = 1 << 1;
const transportEventAccept = 1 << 2;
const transportEventConnect = 1 << 3;
const transportEventReadCallback = 1 << 4;
const transportEventWriteCallback = 1 << 5;
const transportEventReceiveMessageCallback = 1 << 6;
const transportEventSendMessageCallback = 1 << 7;
const transportEventReceiveMessage = 1 << 8;
const transportEventSendMessage = 1 << 9;
const transportEventCustomCallback = 1 << 10;

const transportEventAll = transportEventRead |
    transportEventWrite |
    transportEventAccept |
    transportEventConnect |
    transportEventReadCallback |
    transportEventWriteCallback |
    transportEventReceiveMessageCallback |
    transportEventSendMessageCallback |
    transportEventReceiveMessage |
    transportEventSendMessage |
    transportEventCustomCallback;

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

const transportSocketOptionSocketNonblock = (1 << 0);
const transportSocketOptionSocketClockexec = (1 << 1);
const transportSocketOptionSocketReuseaddr = (1 << 2);
const transportSocketOptionSocketReuseport = (1 << 3);
const transportSocketOptionSocketRcvbuf = (1 << 4);
const transportSocketOptionSocketSndbuf = (1 << 5);
const transportSocketOptionSocketBusyPoll = (1 << 6);
const transportSocketOptionIpTtl = (1 << 7);
const transportSocketOptionTcpCork = (1 << 8);
const transportSocketOptionTcpQuickack = (1 << 9);
const transportSocketOptionTcpDeferAccept = (1 << 10);
const transportSocketOptionTcpNotsentLowat = (1 << 11);
const transportSocketOptionTcpFastopen = (1 << 12);
const transportSocketOptionTcpKeepidle = (1 << 13);
const transportSocketOptionTcpKeepcnt = (1 << 14);
const transportSocketOptionTcpUserTimeout = (1 << 15);
const transportSocketOptionTcpFreebind = (1 << 16);
const transportSocketOptionTcpTransparent = (1 << 17);
const transportSocketOptionTcpRecvorigdstaddr = (1 << 18);
const transportSocketOptionUdpCork = (1 << 19);
