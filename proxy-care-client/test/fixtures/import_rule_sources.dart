/// Sample sources for testing the import-rule checker itself.
abstract final class ImportRuleSources {
  /// A domain file that breaks the rules three ways.
  static const badDomainFile = '''
import 'package:dio/dio.dart';
import "package:flutter/foundation.dart";
export '../../data/dto/user_dto.dart';

class User {}
''';

  /// A domain file that only uses allowed imports.
  static const cleanDomainFile = '''
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/shared/models/result.dart';

// import 'package:dio/dio.dart'; is only a comment and is ignored.
class User {}
''';
}
