#ifndef TRANSPORT_LOGGGER_H
#define TRANSPORT_LOGGGER_H

#include <stdio.h>
#include <stdarg.h>
#include <stdbool.h>
#include <time.h>
#include "dart/dart_api.h"

typedef struct
{
  char *message;
  int level;
} transport_logging_event_t;

enum
{
  LOG_TRACE,
  LOG_DEBUG,
  LOG_INFO,
  LOG_WARN,
  LOG_ERROR,
  LOG_FATAL
};

#define transport_trace(...) transport_logger_log(LOG_TRACE, __FILE__, __LINE__, __VA_ARGS__)
#define transport_debug(...) transport_logger_log(LOG_DEBUG, __FILE__, __LINE__, __VA_ARGS__)
#define transport_info(...) transport_logger_log(LOG_INFO, "", -1, __VA_ARGS__)
#define transport_warn(...) transport_logger_log(LOG_WARN, "", -1, __VA_ARGS__)
#define transport_error(...) transport_logger_log(LOG_ERROR, "", -1, __VA_ARGS__)
#define transport_fatal(...) transport_logger_log(LOG_FATAL, "", -1, __VA_ARGS__)

void transport_logger_initialize(Dart_Port port);

void transport_logger_log(int level, const char *file, int line, const char *fmt, ...);

#endif