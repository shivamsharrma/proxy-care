import 'dart:async';

import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

/// Sends uncaught errors to [reporter]: framework errors through
/// [FlutterError.onError] and asynchronous or platform errors through
/// [PlatformDispatcher.onError].
///
/// The web engine never calls [PlatformDispatcher.onError], so on web the
/// asynchronous errors are caught by [runGuardedZone] instead; install both.
///
/// The previous framework handler still runs, so errors are still printed in
/// debug builds. Returns a callback that restores the previous handlers; tests
/// use it to clean up.
VoidCallback installGlobalErrorHandlers(ErrorReporter reporter) {
  final previousFlutterHandler = FlutterError.onError;
  final previousPlatformHandler = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    reporter.report(
      details.exception,
      details.stack ?? StackTrace.empty,
      context: 'flutter',
    );
    previousFlutterHandler?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    reporter.report(error, stackTrace, context: 'platform');
    return true;
  };

  return () {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  };
}

/// Runs [body] (the whole app start-up, including binding initialization and
/// `runApp`) in a guarded zone, so uncaught asynchronous errors are reported
/// on every platform, including web.
///
/// [reporter] is looked up when an error arrives, because the reporter is
/// only available once [body] has built the provider container. Errors
/// before that (for example an invalid environment configuration) go to
/// the root zone's handler, so a broken start-up fails loudly instead of
/// being swallowed.
void runGuardedZone(
  void Function() body, {
  required ErrorReporter? Function() reporter,
}) {
  runZonedGuarded(body, (error, stackTrace) {
    final current = reporter();
    if (current == null) {
      Zone.root.handleUncaughtError(error, stackTrace);
      return;
    }
    current.report(error, stackTrace, context: 'zone');
  });
}
