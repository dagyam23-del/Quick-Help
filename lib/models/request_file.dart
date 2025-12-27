/// Model representing a file uploaded for a request
class RequestFile {
  final String id;
  final String requestId;
  final String uploadedBy;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String? mimeType;
  final DateTime createdAt;

  RequestFile({
    required this.id,
    required this.requestId,
    required this.uploadedBy,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    this.mimeType,
    required this.createdAt,
  });

  /// Create a RequestFile from JSON
  factory RequestFile.fromJson(Map<String, dynamic> json) {
    return RequestFile(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      uploadedBy: json['uploaded_by'] as String,
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert RequestFile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'uploaded_by': uploadedBy,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get formatted file size (e.g., "1.5 MB")
  String getFormattedSize() {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

