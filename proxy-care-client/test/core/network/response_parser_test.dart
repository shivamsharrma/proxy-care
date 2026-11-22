import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/api_response.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/response_parser.dart';

import '../../helpers/decoding_fixtures.dart';

/// The backend's controllers return their DTOs as bare JSON bodies (Spring
/// MVC `@RestController` return values; `com.proxycare.common.api` has no
/// success envelope in use), always as `application/json`.
void main() {
  group('ResponseParser', () {
    const parser = ResponseParser();

    TestItem? nullableItem(Object? json) =>
        json == null ? null : TestItem.fromJson(json);

    test('a bare JSON object decodes into the DTO', () {
      final response = parser.parse(
        {'id': 'a1', 'label': 'First'},
        TestItem.fromJson,
        statusCode: 200,
      );

      expect(response, isA<ApiResponse<TestItem>>());
      expect(response.data.id, 'a1');
      expect(response.data.label, 'First');
      expect(response.statusCode, 200);
    });

    test('a bare JSON list decodes into the DTOs', () {
      final response = parser.parse(
        [
          {'id': 'a1', 'label': 'First'},
          {'id': 'a2', 'label': 'Second'},
        ],
        listDecoder(TestItem.fromJson),
        statusCode: 200,
      );

      expect(response.data.map((item) => item.id), ['a1', 'a2']);
    });

    test('a bare body with a data property is decoded whole', () {
      Object? received;
      final response = parser.parse(
        {'id': 'a1', 'label': 'First', 'data': 'payload field'},
        (json) {
          received = json;
          return TestItem.fromJson(json);
        },
        statusCode: 200,
      );

      expect(response.data.id, 'a1');
      expect(received, {'id': 'a1', 'label': 'First', 'data': 'payload field'});
    });

    test('an empty body (204) decodes as null', () {
      for (final body in <Object?>[null, '', '  ']) {
        final response = parser.parse(body, ignoreBody, statusCode: 204);
        expect(response.statusCode, 204);
      }
    });

    test('a nullable decoder returns null for an empty or null body', () {
      for (final (body, status) in <(Object?, int)>[
        (null, 204),
        ('', 204),
        ('  ', 204),
        ('null', 200),
      ]) {
        final response = parser.parse<TestItem?>(
          body,
          nullableItem,
          statusCode: status,
        );

        expect(response.data, isNull, reason: '$body');
        expect(response.statusCode, status, reason: '$body');
      }
    });

    test('an empty body with a non-null decoder is an invalid response', () {
      expect(
        () => parser.parse(null, TestItem.fromJson, statusCode: 204),
        throwsInvalidResponse,
      );
    });

    test('a bare body sent as text is still read', () {
      final response = parser.parse(
        jsonEncode({'id': 'a1', 'label': 'First'}),
        TestItem.fromJson,
        statusCode: 200,
      );

      expect(response.data.id, 'a1');
    });

    test('a non-JSON text body is an invalid response', () {
      for (final body in ['<html><body>OK</body></html>', 'OK']) {
        expect(
          () => parser.parse(body, TestItem.fromJson, statusCode: 200),
          throwsInvalidResponse,
          reason: body,
        );
        expect(
          () => parser.parse(body, ignoreBody, statusCode: 200),
          throwsInvalidResponse,
          reason: '$body (ignored body)',
        );
      }
    });

    test('a bare body that does not match the DTO is an invalid response', () {
      expect(
        () => parser.parse({'id': 1}, TestItem.fromJson, statusCode: 200),
        throwsInvalidResponse,
      );
    });

    test('keeps headers by lower-case name and exposes ETag', () {
      final response = parser.parse(
        {'id': 'a1', 'label': 'First'},
        TestItem.fromJson,
        statusCode: 201,
        headers: {
          'ETag': ['"3"'],
          'Location': ['/api/v1/items/a1'],
        },
      );

      expect(response.data.id, 'a1');
      expect(response.statusCode, 201);
      expect(response.etag, '"3"');
      expect(response.location, '/api/v1/items/a1');
      expect(response.header('etag'), '"3"');
      expect(response.header('X-Missing'), isNull);
      expect(
        () => response.headers['etag'] = const [],
        throwsUnsupportedError,
      );
    });
  });
}
