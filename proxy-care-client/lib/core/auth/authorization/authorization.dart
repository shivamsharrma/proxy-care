/// Client-side authorization primitives.
///
/// **Not a security boundary.** These only decide what the UI offers. The
/// Spring Boot API validates every JWT and enforces every permission on its
/// own; a client decision can always be bypassed.
library;

/// A named role, e.g. as issued in a server-controlled token claim. Only the
/// two app roles are defined here; features define any others they need.
final class Role {
  /// Creates a role.
  const Role(this.name);

  /// The family member who books care (the User app).
  static const user = Role('USER');

  /// The caretaker who takes the patient to hospital (the Caretaker app).
  static const caretaker = Role('CARETAKER');

  /// Role identifier as issued by the server.
  final String name;

  @override
  bool operator ==(Object other) => other is Role && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Role($name)';
}

/// A named permission (an action on a kind of resource).
final class Permission {
  /// Creates a permission.
  const Permission(this.name);

  /// Permission identifier.
  final String name;

  @override
  bool operator ==(Object other) => other is Permission && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Permission($name)';
}

/// The outcome of an authorization check.
sealed class AuthorizationDecision {
  const AuthorizationDecision();

  /// Whether the action is allowed.
  bool get isAllowed => this is Allowed;
}

/// The action is allowed.
final class Allowed extends AuthorizationDecision {
  /// Creates an allowed decision.
  const Allowed();
}

/// Why an action is denied.
enum DenialReason {
  /// Nobody is signed in.
  unauthenticated,

  /// The user's roles do not grant the permission.
  missingPermission,
}

/// The action is denied.
final class Denied extends AuthorizationDecision {
  /// Creates a denied decision.
  const Denied(this.reason);

  /// Why.
  final DenialReason reason;
}

/// Decides which permissions a set of roles grants.
abstract interface class PermissionEvaluator {
  /// Whether [roles] grant [permission].
  bool grants(Set<Role> roles, Permission permission);
}

/// A [PermissionEvaluator] from a fixed role → permissions table.
final class RolePermissionPolicy implements PermissionEvaluator {
  /// Creates a policy; roles not in [grantsByRole] grant nothing.
  const RolePermissionPolicy(this.grantsByRole);

  /// An empty policy: nothing is granted.
  static const RolePermissionPolicy none = RolePermissionPolicy({});

  /// Permissions per role.
  final Map<Role, Set<Permission>> grantsByRole;

  @override
  bool grants(Set<Role> roles, Permission permission) => roles.any(
    (role) => grantsByRole[role]?.contains(permission) ?? false,
  );
}

/// Checks permissions for the signed-in user's roles.
final class AuthorizationService {
  /// Creates a service using [evaluator].
  const AuthorizationService(this.evaluator);

  /// Role → permission rules.
  final PermissionEvaluator evaluator;

  /// The decision for [permission]; [roles] is null when nobody is signed
  /// in.
  AuthorizationDecision decide(Set<Role>? roles, Permission permission) {
    if (roles == null) return const Denied(DenialReason.unauthenticated);
    return evaluator.grants(roles, permission)
        ? const Allowed()
        : const Denied(DenialReason.missingPermission);
  }
}
