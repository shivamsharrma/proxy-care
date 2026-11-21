import '../error/error_reporter.dart';

/// Clears per-user data when a session ends (sign-out or expiry). Pure
/// Dart.
///
/// Anything that keeps data for the signed-in user (a cache, a draft, a
/// push token, an analytics identity) registers a task once; the tasks run
/// when the authentication state leaves `Authenticated` (wired in
/// `core/di/platform_providers.dart`). The session itself (tokens in
/// secure storage) is cleared by `AuthenticationSession`, not here.
final class SessionCleanup {
  /// Creates the registry; failures go to [reporter].
  SessionCleanup(this.reporter);

  /// Where task failures go.
  final ErrorReporter reporter;

  final Map<String, Future<void> Function()> _tasks = {};

  /// Registers [task] under [name]; a later registration replaces it.
  void register(String name, Future<void> Function() task) =>
      _tasks[name] = task;

  /// Runs every task. A failing task is reported (context
  /// `session-cleanup:<name>`) and the others still run; never throws.
  Future<void> run() async {
    for (final MapEntry(key: name, value: task) in _tasks.entries) {
      try {
        await task();
      } on Object catch (error, stackTrace) {
        reporter.report(error, stackTrace, context: 'session-cleanup:$name');
      }
    }
  }
}
