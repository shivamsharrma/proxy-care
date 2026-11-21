import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Replaces the widget Flutter shows in place of a widget whose `build`
/// threw.
///
/// In debug builds ([showDetails] true) the framework's own error widget is
/// kept, so developers see the exception. Otherwise the failed widget
/// renders as empty space: no message, exception or stack trace reaches the
/// user, and no custom error screen is shown. The error itself is still
/// reported through `FlutterError.onError`.
///
/// Returns a callback that restores the previous builder.
void Function() installErrorWidgetBuilder({bool showDetails = kDebugMode}) {
  final previous = ErrorWidget.builder;
  if (!showDetails) {
    ErrorWidget.builder = (details) => const SizedBox.shrink();
  }
  return () => ErrorWidget.builder = previous;
}
