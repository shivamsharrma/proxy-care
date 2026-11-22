import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';

/// A feature-agnostic DTO for decoding tests: `{"id": …, "label": …}`.
final class TestItem {
  /// Creates an item.
  const TestItem(this.id, this.label);

  /// Decodes `{"id": String, "label": String}`; any other shape throws a
  /// `TypeError`, as generated `fromJson` code does.
  factory TestItem.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return TestItem(map['id']! as String, map['label']! as String);
  }

  /// `id`.
  final String id;

  /// `label`.
  final String label;
}

/// Matches a call or future that throws `ServerException.invalidResponse`.
Matcher get throwsInvalidResponse => throwsA(
  isA<ServerException>().having(
    (e) => e.invalidResponse,
    'invalidResponse',
    isTrue,
  ),
);
