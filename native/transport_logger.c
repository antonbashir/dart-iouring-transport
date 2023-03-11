#include "transport_logger.h"
#include "transport_constants.h"
#include "dart/dart_native_api.h"

static Dart_Port logging_port;

void transport_logger_log(int level, const char *file, int line, const char *format, ...)
{
  va_list arguments;
  transport_logging_event_t *event = malloc(sizeof(transport_logging_event_t));
  event->level = level;
  event->message = malloc(TRANSPORT_NATIVE_LOG_BUFFER);
  va_start(arguments, format);
  sprintf(event->message, "[native] ");
  if (line != -1)
  {
    sprintf(
        event->message,
        "%s:%d: ",
        file,
        line);
  }
  vsprintf(event->message, format, arguments);
  va_end(arguments);

  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)event;
  Dart_PostCObject(logging_port, &dart_object);
}

void transport_logger_initialize(Dart_Port port)
{
  logging_port = port;
}