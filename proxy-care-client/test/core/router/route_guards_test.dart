import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/authorization/authorization.dart';
import 'package:proxy_care_client/core/router/deep_link_policy.dart';
import 'package:proxy_care_client/core/router/redirect_destinations.dart';
import 'package:proxy_care_client/core/router/route_access.dart';
import 'package:proxy_care_client/core/router/route_guards.dart';

const _destinations = RedirectDestinations(signIn: '/sign-in', home: '/start');
const _user = AuthenticatedUser(id: 'u1');

RouteRequest _request(
  String location, {
  RouteAccess? access = const AuthenticatedAccess(),
  AuthenticationState auth = const Unauthenticated(),
  bool isUnmatched = false,
}) {
  final uri = Uri.parse(location);
  return RouteRequest(
    uri: uri,
    matchedLocation: uri.path,
    access: access,
    authentication: auth,
    isUnmatched: isUnmatched,
  );
}

Map<String, String> _query(String? location) =>
    Uri.parse(location!).queryParameters;

void main() {
  group('AuthenticationGuard', () {
    const guard = AuthenticationGuard(_destinations);

    test('public routes are always allowed', () {
      for (final auth in const [
        Unauthenticated(),
        AuthenticationInitializing(),
        SessionExpired(),
        Authenticated(user: _user),
      ]) {
        expect(
          guard.redirect(
            _request('/p', access: const PublicAccess(), auth: auth),
          ),
          isNull,
        );
      }
    });

    test('signed-out users go to sign-in with the destination kept', () {
      final target = guard.redirect(_request('/visits/1?tab=notes'));
      expect(Uri.parse(target!).path, '/sign-in');
      expect(_query(target), {'from': '/visits/1?tab=notes'});
    });

    test('a route without declared access is protected', () {
      expect(guard.redirect(_request('/x', access: null)), isNotNull);
    });

    test('an expired session says why', () {
      final target = guard.redirect(
        _request('/visits', auth: const SessionExpired()),
      );
      expect(_query(target), {'from': '/visits', 'reason': 'sessionExpired'});
      const custom = AuthenticationGuard(
        RedirectDestinations(signIn: '/sign-in', sessionExpired: '/expired'),
      );
      expect(
        Uri.parse(
          custom.redirect(_request('/visits', auth: const SessionExpired()))!,
        ).path,
        '/expired',
      );
    });

    test('initializing users wait on the pending location', () {
      final target = guard.redirect(
        _request('/visits', auth: const AuthenticationInitializing()),
      );
      expect(Uri.parse(target!).path, RouterLocations.pending);
      expect(_query(target)['from'], '/visits');
    });

    test('the pending location resumes once the state is known', () {
      const pending = '${RouterLocations.pending}?from=%2Fvisits';
      expect(
        guard.redirect(
          _request(pending, auth: const AuthenticationInitializing()),
        ),
        isNull,
      );
      expect(guard.redirect(_request(pending)), '/visits');
      expect(
        guard.redirect(_request(RouterLocations.pending)),
        '/start',
        reason: 'no from: home',
      );
    });

    test('without a sign-in destination, the fallback is used', () {
      const bare = AuthenticationGuard(RedirectDestinations());
      expect(
        Uri.parse(bare.redirect(_request('/visits'))!).path,
        RouterLocations.signInRequired,
      );
    });

    test('guest-only routes send signed-in users on', () {
      const signedIn = Authenticated(user: _user);
      expect(
        guard.redirect(
          _request('/sign-in', access: const GuestOnlyAccess(), auth: signedIn),
        ),
        '/start',
      );
      expect(
        guard.redirect(
          _request(
            '/sign-in?from=%2Fvisits%2F1',
            access: const GuestOnlyAccess(),
            auth: signedIn,
          ),
        ),
        '/visits/1',
      );
      expect(
        guard.redirect(
          _request(
            '/sign-in?from=https%3A%2F%2Fevil.example',
            access: const GuestOnlyAccess(),
            auth: signedIn,
          ),
        ),
        '/start',
        reason: 'an unsafe from is ignored',
      );
      expect(
        guard.redirect(_request('/sign-in', access: const GuestOnlyAccess())),
        isNull,
      );
    });

    test('never redirects to the current location (no loops)', () {
      const selfSignIn = AuthenticationGuard(
        RedirectDestinations(signIn: '/visits'),
      );
      expect(selfSignIn.redirect(_request('/visits')), isNull);
      const selfHome = AuthenticationGuard(RedirectDestinations(home: '/g'));
      expect(
        selfHome.redirect(
          _request(
            '/g',
            access: const GuestOnlyAccess(),
            auth: const Authenticated(user: _user),
          ),
        ),
        isNull,
      );
    });

    test('unmatched locations are left to the not-found page', () {
      expect(guard.redirect(_request('/nope', isUnmatched: true)), isNull);
    });
  });

  group('AuthorizationGuard', () {
    const admin = Role('admin');
    const read = Permission('reports.read');
    final authorizer = RouteAuthorizer(
      authorization: AuthorizationService(
        RolePermissionPolicy({
          admin: {read},
        }),
      ),
      features: const FeatureFlagAccessPolicy({'beta_tools'}),
    );
    final guard = AuthorizationGuard(
      authorizer: authorizer,
      destinations: _destinations,
    );
    Authenticated user([Set<Role> roles = const {}]) => Authenticated(
      user: AuthenticatedUser(id: 'u1', roles: roles),
    );

    test('checks roles, permissions and features', () {
      final byRole = AuthenticatedAccess(anyOfRoles: {admin});
      final byPermission = AuthenticatedAccess(permissions: {read});
      const byFeature = AuthenticatedAccess(feature: 'beta_tools');
      const offFeature = AuthenticatedAccess(feature: 'other');

      expect(authorizer.check(byRole, _user), RouteDenial.missingRole);
      expect(
        authorizer.check(byPermission, _user),
        RouteDenial.missingPermission,
      );
      expect(
        authorizer.check(offFeature, _user),
        RouteDenial.featureUnavailable,
      );
      expect(authorizer.check(byFeature, _user), isNull);
      final adminUser = user({admin}).user;
      expect(authorizer.check(byRole, adminUser), isNull);
      expect(authorizer.check(byPermission, adminUser), isNull);
    });

    test('denied users go to the forbidden location', () {
      final access = AuthenticatedAccess(anyOfRoles: {admin});
      expect(
        guard.redirect(_request('/admin', access: access, auth: user())),
        RouterLocations.forbidden,
      );
      expect(
        guard.redirect(_request('/admin', access: access, auth: user({admin}))),
        isNull,
      );
    });

    test('leaves signed-out users and public routes alone', () {
      final access = AuthenticatedAccess(anyOfRoles: {admin});
      expect(guard.redirect(_request('/admin', access: access)), isNull);
      expect(
        guard.redirect(
          _request('/p', access: const PublicAccess(), auth: user()),
        ),
        isNull,
      );
    });
  });

  group('DeepLinkGuard', () {
    const guard = DeepLinkGuard(
      policy: DeepLinkPolicy(allowedHosts: {'links.example.test'}),
      destinations: _destinations,
    );

    test('turns accepted links into locations, others into not found', () {
      expect(guard.redirect(_request('/visits/1')), isNull);
      expect(
        guard.redirect(_request('https://links.example.test/visits/1?x=y')),
        '/visits/1?x=y',
      );
      expect(
        guard.redirect(_request('https://evil.example/visits/1')),
        RouterLocations.notFound,
      );
    });
  });

  test('RedirectPipeline: first redirect wins, self-redirects allow', () {
    final calls = <String>[];
    final pipeline = RedirectPipeline([
      _FixedGuard('/visits', calls, 'self'),
      _FixedGuard('/elsewhere', calls, 'first'),
      _FixedGuard('/never', calls, 'second'),
    ]);
    expect(pipeline.redirect(_request('/visits')), '/elsewhere');
    expect(calls, ['self', 'first']);
  });
}

final class _FixedGuard implements RouteGuard {
  _FixedGuard(this.target, this.calls, this.label);

  final String target;
  final List<String> calls;
  final String label;

  @override
  String? redirect(RouteRequest request) {
    calls.add(label);
    return target;
  }
}
