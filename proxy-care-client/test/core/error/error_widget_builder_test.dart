import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/error_widget_builder.dart';

class _Throws extends StatelessWidget {
  const _Throws();

  @override
  Widget build(BuildContext context) => throw StateError('secret detail');
}

void main() {
  late ErrorWidgetBuilder original;
  setUp(() => original = ErrorWidget.builder);
  tearDown(() => ErrorWidget.builder = original);

  test('debug builds keep the framework error widget', () {
    final restore = installErrorWidgetBuilder(showDetails: true);

    expect(ErrorWidget.builder, same(original));
    restore();
  });

  testWidgets('otherwise a failed widget renders empty, without details', (
    tester,
  ) async {
    final restore = installErrorWidgetBuilder(showDetails: false);
    addTearDown(restore);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: _Throws()),
      ),
    );

    expect(tester.takeException(), isStateError);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('secret detail'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  test('the returned callback restores the previous builder', () {
    final restore = installErrorWidgetBuilder(showDetails: false);
    expect(ErrorWidget.builder, isNot(same(original)));

    restore();
    expect(ErrorWidget.builder, same(original));
  });
}
