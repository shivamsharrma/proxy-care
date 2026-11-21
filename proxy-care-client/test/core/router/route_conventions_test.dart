import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/router/deep_link_policy.dart';
import 'package:proxy_care_client/core/router/intended_destination.dart';
import 'package:proxy_care_client/core/router/navigation_payload.dart';
import 'package:proxy_care_client/core/router/route_access.dart';
import 'package:proxy_care_client/core/router/route_conventions.dart';
import 'package:proxy_care_client/core/router/route_definition.dart';

void main() {
  group('RouteConventions', () {
    test('route names are <module>.<screen> in lowerCamelCase', () {
      for (final name in ['bookings.list', 'bookings.detail.edit', 'a.b2']) {
        expect(RouteConventions.isRouteName(name), isTrue, reason: name);
      }
      for (final name in ['bookings', 'Bookings.list', 'bookings.', 'b-x.y']) {
        expect(RouteConventions.isRouteName(name), isFalse, reason: name);
      }
    });

    test('paths use kebab-case segments and :camelCase parameters', () {
      expect(RouteConventions.pathProblems('/', absolute: true), isEmpty);
      expect(
        RouteConventions.pathProblems('/care-visits/:visitId', absolute: true),
        isEmpty,
      );
      expect(RouteConventions.pathProblems('edit', absolute: false), isEmpty);
      expect(
        RouteConventions.pathProblems('edit', absolute: true),
        [contains('must start with "/"')],
      );
      expect(
        RouteConventions.pathProblems('/edit', absolute: false),
        [contains('must not start')],
      );
      expect(
        RouteConventions.pathProblems('/Care_Visits/:visit_id', absolute: true),
        hasLength(2),
      );
      expect(
        RouteConventions.pathProblems(r'/items/:id(\d+)', absolute: true),
        hasLength(1),
      );
    });
  });

  group('RouteDefinition', () {
    const list = RouteDefinition(
      name: 'visits.list',
      path: '/visits',
      access: AuthenticatedAccess(),
    );
    const detail = RouteDefinition(
      name: 'visits.detail',
      path: ':visitId',
      parent: list,
    );
    const note = RouteDefinition(
      name: 'visits.note',
      path: 'notes/:noteId',
      parent: detail,
    );

    test('derives the full path and parameters from its parents', () {
      expect(note.fullPath, '/visits/:visitId/notes/:noteId');
      expect(note.pathParameterNames, ['visitId', 'noteId']);
      const root = RouteDefinition(name: 'x.root', path: '/');
      const child = RouteDefinition(name: 'x.child', path: 'a', parent: root);
      expect(child.fullPath, '/a');
    });

    test('builds encoded locations with query parameters', () {
      expect(
        detail.location(pathParameters: {'visitId': 'a b/c'}),
        '/visits/a%20b%2Fc',
      );
      expect(
        list.location(queryParameters: {'status': 'open', 'page': '2'}),
        '/visits?status=open&page=2',
      );
    });

    test('rejects missing, unknown, empty and reserved parameters', () {
      expect(() => detail.location(), throwsArgumentError);
      expect(
        () => detail.location(pathParameters: {'visitId': '1', 'x': '2'}),
        throwsArgumentError,
      );
      expect(
        () => detail.location(pathParameters: {'visitId': ''}),
        throwsArgumentError,
      );
      expect(
        () => list.location(queryParameters: {'from': '/x'}),
        throwsArgumentError,
      );
      expect(
        () => list.location(queryParameters: {'Bad-Key': '1'}),
        throwsArgumentError,
      );
    });

    test('registers a GoRoute carrying its name and access', () {
      final route = list.route(builder: (_, _) => throw UnimplementedError());
      expect(route.name, 'visits.list');
      expect(route.path, '/visits');
      expect(
        RouteAccess.fromMetadata(route.metadata),
        isA<AuthenticatedAccess>(),
      );
      expect(
        detail.route(builder: (_, _) => throw UnimplementedError()).metadata,
        isNull,
        reason: 'inherits the parent',
      );
    });
  });

  group('IntendedDestination', () {
    test('accepts in-app locations only', () {
      expect(
        IntendedDestination.sanitize('/visits/1?tab=a'),
        '/visits/1?tab=a',
      );
      expect(IntendedDestination.sanitize('/visits#frag'), '/visits');
      for (final unsafe in [
        null,
        '',
        'visits',
        '//evil.example/x',
        'https://evil.example/x',
        r'/\evil.example',
        '/a/../b',
        '/${'a' * IntendedDestination.maxLength}',
      ]) {
        expect(IntendedDestination.sanitize(unsafe), isNull, reason: unsafe);
      }
    });

    test('attaches and reads back the interrupted location', () {
      final target = IntendedDestination.attach(
        '/sign-in?mode=phone',
        intended: '/visits/1?tab=a',
        reason: 'sessionExpired',
      );
      final uri = Uri.parse(target);
      expect(uri.path, '/sign-in');
      expect(uri.queryParameters, {
        'mode': 'phone',
        'from': '/visits/1?tab=a',
        'reason': 'sessionExpired',
      });
      expect(IntendedDestination.of(uri), '/visits/1?tab=a');
      expect(
        IntendedDestination.of(Uri.parse('/sign-in?from=https://evil.example')),
        isNull,
      );
    });
  });

  group('DeepLinkPolicy', () {
    const policy = DeepLinkPolicy(allowedHosts: {'links.example.test'});

    test('opens paths and links on allowed hosts', () {
      expect(policy.resolve(Uri.parse('/visits/1?a=b')), '/visits/1?a=b');
      expect(
        policy.resolve(Uri.parse('https://LINKS.example.test/visits/1?a=b#x')),
        '/visits/1?a=b',
      );
      expect(policy.resolve(Uri.parse('https://links.example.test')), '/');
    });

    test('rejects other hosts, schemes and user info', () {
      for (final link in [
        'https://evil.example/visits/1',
        'http://links.example.test/visits/1',
        'proxycare://visits/1',
        'https://user@links.example.test/visits/1',
      ]) {
        expect(policy.resolve(Uri.parse(link)), isNull, reason: link);
      }
      expect(
        const DeepLinkPolicy().resolve(
          Uri.parse('https://links.example.test/'),
        ),
        isNull,
        reason: 'no domain is configured by default',
      );
    });
  });

  group('NavigationPayload', () {
    test('accepts a typed payload with string data', () {
      final payload = NavigationPayload.tryParse({
        'type': 'visits.updated',
        'data': {'visitId': '42'},
      });
      expect(payload?.type, 'visits.updated');
      expect(payload?.data, {'visitId': '42'});
      expect(() => payload!.data['x'] = 'y', throwsUnsupportedError);
      expect(
        NavigationPayload.tryParse({'type': 'visits.updated'})?.data,
        isEmpty,
      );
    });

    test('rejects malformed payloads', () {
      for (final raw in <Object?>[
        null,
        'visits.updated',
        <String, Object?>{},
        {'type': 'visits'},
        {'type': 'visits.updated', 'data': 'x'},
        {
          'type': 'visits.updated',
          'data': {'visitId': 42},
        },
        {
          'type': 'visits.updated',
          'data': {'visit-id': '42'},
        },
        {
          'type': 'visits.updated',
          'data': {'note': 'x' * (NavigationPayload.maxValueLength + 1)},
        },
        {
          'type': 'visits.updated',
          'data': {
            for (var i = 0; i <= NavigationPayload.maxEntries; i++) 'k$i': 'v',
          },
        },
      ]) {
        expect(NavigationPayload.tryParse(raw), isNull, reason: '$raw');
      }
    });
  });
}
