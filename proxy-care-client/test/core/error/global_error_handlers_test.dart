import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/error/global_error_handlers.dart';

import '../../mocks/core_mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  late MockErrorReporter reporter;
  late List<FlutterErrorDetails> forwarded;
  late FlutterExceptionHandler? originalFlutterHandler;

  setUp(() {
    reporter = MockErrorReporter();
    forwarded = [];
    originalFlutterHandler = FlutterError.onError;
    // Stand-in for the framework's default handler.
    FlutterError.onError = forwarded.add;
  });

  tearDown(() => FlutterError.onError = originalFlutterHandler);

  test('reports framework errors and still runs the previous handler', () {
    final restore = installGlobalErrorHandlers(reporter);
    addTearDown(restore);
    final details = FlutterErrorDetails(exception: StateError('build'));

    FlutterError.onError!(details);

    verify(
      () => reporter.report(details.exception, any(), context: 'flutter'),
    ).called(1);
    expect(forwarded, [details]);
  });

  test('reports platform errors and marks them handled', () {
    final restore = installGlobalErrorHandlers(reporter);
    addTearDown(restore);
    final error = StateError('async');

    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.empty,
    );

    expect(handled, isTrue);
    verify(
      () => reporter.report(error, StackTrace.empty, context: 'platform'),
    ).called(1);
  });

  test('the returned callback restores the previous handlers', () {
    final previousFlutterHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;

    final restore = installGlobalErrorHandlers(reporter);
    expect(FlutterError.onError, isNot(same(previousFlutterHandler)));

    restore();

    expect(FlutterError.onError, same(previousFlutterHandler));
    expect(
      PlatformDispatcher.instance.onError,
      same(previousPlatformHandler),
    );
  });

  test('runGuardedZone reports uncaught asynchronous errors', () async {
    final reported = Completer<Object>();
    when(() => reporter.report(any(), any(), context: 'zone')).thenAnswer(
      (invocation) => reported.complete(invocation.positionalArguments.first!),
    );

    runGuardedZone(() {
      // An unawaited failing future: on web only the zone sees it.
      unawaited(Future<void>.error(StateError('async')));
    }, reporter: () => reporter);

    expect(await reported.future, isA<StateError>());
  });
}
