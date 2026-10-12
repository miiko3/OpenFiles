import 'dart:io';
enum FsBackend {
  saf,
  local,
  transient,
}
class FsLocation {
  const FsLocation.saf({required this.treeUri, required this.docId})
      : backend = FsBackend.saf,
        path = null;
  const FsLocation.local(this.path) : backend = FsBackend.local, treeUri = null, docId = null;
  const FsLocation.transient(this.path)
      : backend = FsBackend.transient,
        treeUri = null,
        docId = null;
  final FsBackend backend;
  final String? treeUri;
  final String? docId;
  final String? path;
  bool get isSaf => backend == FsBackend.saf;
  bool get isLocal => backend == FsBackend.local;
  FsLocation child(String childDocId) => FsLocation.saf(
        treeUri: treeUri!,
        docId: childDocId,
      );
  Map<String, dynamic> toArgs() => {
        if (treeUri != null) 'treeUri': treeUri,
        if (docId != null) 'docId': docId,
        if (path != null) 'path': path,
      };
  static FsLocation fromMap(Map<dynamic, dynamic> m) {
    final tree = m['treeUri'] as String?;
    final doc = m['docId'] as String?;
    if (tree != null && doc != null) return FsLocation.saf(treeUri: tree, docId: doc);
    final p = m['path'] as String?;
    if (p != null) {
      return FsLocation.local(p);
    }
    final uri = m['uri'] as String?;
    if (uri != null) return FsLocation.transient(uri);
    throw FormatException('Unrecognised location $m');
  }
  @override
  bool operator ==(Object other) =>
      other is FsLocation &&
      other.backend == backend &&
      other.treeUri == treeUri &&
      other.docId == docId &&
      other.path == path;
  @override
  int get hashCode => Object.hash(backend, treeUri, docId, path);
  @override
  String toString() => 'FsLocation($backend, ${treeUri ?? path})';
}
class FsNode {
  FsNode({
    required this.location,
    required this.name,
    required this.isDirectory,
    required this.mime,
    this.size = -1,
    DateTime? modified,
    this.canWrite = false,
    this.canDelete = false,
    this.canRename = false,
    this.displayPath = '',
  }) : modified = modified ?? DateTime.fromMillisecondsSinceEpoch(0);
  factory FsNode.local(File file, {String? displayPath}) => FsNode(
        location: FsLocation.local(file.path),
        name: file.uri.pathSegments.isEmpty
            ? file.path
            : file.uri.pathSegments.last,
        isDirectory: false,
        mime: 'application/octet-stream',
        size: file.existsSync() ? file.lengthSync() : -1,
        modified: file.existsSync() ? file.lastModifiedSync() : DateTime.now(),
        canWrite: true,
        canDelete: true,
        canRename: true,
        displayPath: displayPath ?? file.path,
      );
  final FsLocation location;
  final String name;
  final bool isDirectory;
  final String mime;
  final int size;
  final DateTime modified;
  final bool canWrite;
  final bool canDelete;
  final bool canRename;
  final String displayPath;
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
  String get ext => extension;
  bool get isHidden => name.startsWith('.');
  FsNode copyWith({String? name, int? size, DateTime? modified, bool? canWrite}) => FsNode(
        location: location,
        name: name ?? this.name,
        isDirectory: isDirectory,
        mime: mime,
        size: size ?? this.size,
        modified: modified ?? this.modified,
        canWrite: canWrite ?? this.canWrite,
        canDelete: canDelete,
        canRename: canRename,
        displayPath: displayPath,
      );
}
class TreeRoot {
  const TreeRoot({
    required this.treeUri,
    required this.label,
    this.docId = '',
    this.lastVisited,
  });
  final String treeUri;
  final String label;
  final String docId;
  final DateTime? lastVisited;
  Map<String, dynamic> toJson() => {
        'treeUri': treeUri,
        'label': label,
        'docId': docId,
        'lastVisited': lastVisited?.millisecondsSinceEpoch,
      };
  static TreeRoot fromJson(Map<String, dynamic> m) => TreeRoot(
        treeUri: m['treeUri'] as String,
        label: (m['label'] as String?) ?? 'Storage',
        docId: (m['docId'] as String?) ?? '',
        lastVisited: m['lastVisited'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['lastVisited'] as int),
      );
}
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 0) return '--';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final s = value.toStringAsFixed(value >= 100 ? 0 : decimals);
  return '$s ${units[unit]}';
}
