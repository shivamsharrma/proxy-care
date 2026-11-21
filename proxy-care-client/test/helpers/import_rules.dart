/// A dependency rule: files whose path matches [appliesTo] must not have an
/// import or export whose URI contains any of [forbidden].
final class ImportRule {
  /// Creates a rule named [name].
  const ImportRule({
    required this.name,
    required this.appliesTo,
    required this.forbidden,
  });

  /// Short description used in failure messages.
  final String name;

  /// Matches the package-relative paths (for example `lib/core/x.dart`) this
  /// rule applies to.
  final Pattern appliesTo;

  /// Substrings that must not appear in an import or export URI.
  final List<String> forbidden;
}

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// The URIs of every import and export directive in [source].
List<String> directivesOf(String source) {
  return [
    for (final match in _directive.allMatches(source)) match.group(1)!,
  ];
}

/// Describes every way the file at [path] with contents [source] breaks one
/// of [rules]. Empty when the file is clean.
List<String> violationsOf(String path, String source, List<ImportRule> rules) {
  final uris = directivesOf(source);
  return [
    for (final rule in rules)
      if (rule.appliesTo.allMatches(path).isNotEmpty)
        for (final uri in uris)
          for (final forbidden in rule.forbidden)
            if (uri.contains(forbidden)) '$path imports $uri (${rule.name})',
  ];
}
