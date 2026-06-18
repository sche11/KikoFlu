import '../utils/file_tree_utils.dart';

class FileDeleteRequest {
  const FileDeleteRequest({
    required this.title,
    required this.relativePath,
  });

  final String title;
  final String relativePath;
}

class FileDeleteRequestBuilder {
  const FileDeleteRequestBuilder();

  FileDeleteRequest build({
    required dynamic file,
    required String parentPath,
    required String unknownTitle,
  }) {
    final title = FileTreeUtils.titleOf(file, defaultValue: unknownTitle);
    return FileDeleteRequest(
      title: title,
      relativePath: parentPath.isEmpty ? title : '$parentPath/$title',
    );
  }
}
