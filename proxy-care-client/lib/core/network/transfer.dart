import 'dart:typed_data';

/// A file to send in a multipart upload. Built from bytes so it works on
/// every platform, including web (no file paths).
final class UploadFile {
  /// Creates an upload file.
  const UploadFile({
    required this.field,
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  /// Form field name.
  final String field;

  /// File content.
  final Uint8List bytes;

  /// File name sent to the server.
  final String filename;

  /// Media type such as `image/jpeg` or `application/pdf`; guessed from
  /// [filename] when null.
  final String? contentType;
}

/// A downloaded file, held in memory.
final class DownloadedFile {
  /// Creates a downloaded file.
  const DownloadedFile({
    required this.bytes,
    this.contentType,
    this.filename,
  });

  /// File content.
  final Uint8List bytes;

  /// The `Content-Type` header.
  final String? contentType;

  /// The file name from `Content-Disposition`, if any.
  final String? filename;
}

/// Reports transfer progress: bytes done and total bytes (-1 when unknown).
typedef TransferProgress = void Function(int done, int total);
