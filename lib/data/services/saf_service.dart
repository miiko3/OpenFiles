import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/fs_node.dart';
import 'file_kinds.dart';
class SafException implements Exception {
  SafException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'SafException($code): $message';
}
class SafService {
  SafService._();
  static final SafService instance = SafService._();
  static const _saf = MethodChannel('com.openfiles/saf');
  static const _inbox = MethodChannel('com.openfiles/inbox');
Future<TreeRoot?> pickTree() async {
    final res = await _saf.invokeMethod<Map<dynamic, dynamic>>('pickTree');
    if (res == null) return null;
    return TreeRoot(
      treeUri: res['treeUri'] as String,
      docId: (res['docId'] as String?) ?? '',
      label: (res['label'] as String?) ?? 'Хранилище',
    );
  }
  Future<List<FsLocation>> pickFiles({bool multiple = false, String? mime}) async {
    final res = await _saf.invokeListMethod<Map<dynamic, dynamic>>(
      'pickFiles',
      {'multiple': multiple, 'mime': mime},
    );
    if (res == null) return const [];
    return res
        .map((m) => FsLocation.transient(m['uri'] as String))
        .toList(growable: false);
  }
  Future<bool> persist(String uri, {bool write = false}) async =>
      await _saf.invokeMethod<bool>('persistPermission', {'uri': uri, 'write': write}) ??
      false;
  Future<bool> release(String uri) async =>
      await _saf.invokeMethod<bool>('releasePermission', {'uri': uri}) ?? false;
  Future<bool> hasPermission(String uri) async =>
      await _saf.invokeMethod<bool>('hasPermission', {'uri': uri}) ?? false;
  Future<List<FsNode>> listChildren(FsLocation location) async {
    if (location.isLocal) return _listLocal(location.path!);
    final res = await _saf.invokeListMethod<Map<dynamic, dynamic>>(
      'listChildren',
      location.toArgs(),
    );
    if (res == null) return const [];
    return res.map(_nodeFromMap).toList(growable: false);
  }
  List<FsNode> _listLocal(String dir) {
    final out = <FsNode>[];
    final directory = Directory(dir);
    if (!directory.existsSync()) return out;
    final children = directory.listSync();
    for (final child in children) {
      final stat = child.statSync();
      out.add(
        FsNode(
          location: FsLocation.local(child.path),
          name: p.basename(child.path),
          isDirectory: child is Directory,
          mime: child is Directory
              ? 'vnd.android.document/directory'
              : lookupMime(child.path),
          size: child is Directory ? -1 : stat.size,
          modified: stat.modified,
          canWrite: true,
          canDelete: true,
          canRename: true,
          displayPath: child.path,
        ),
      );
    }
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }
  FsNode _nodeFromMap(Map<dynamic, dynamic> m) {
    final modifiedMillis = (m['modified'] as num?)?.toInt() ?? 0;
    return FsNode(
      location: FsLocation.fromMap(m),
      name: (m['name'] as String?) ?? '',
      isDirectory: (m['isDir'] as bool?) ?? false,
      mime: (m['mime'] as String?) ?? 'application/octet-stream',
      size: (m['size'] as num?)?.toInt() ?? -1,
      modified: modifiedMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(modifiedMillis)
          : DateTime.now(),
      canWrite: (m['canWrite'] as bool?) ?? false,
      canDelete: (m['canDelete'] as bool?) ?? false,
      canRename: (m['canRename'] as bool?) ?? false,
      displayPath: (m['docId'] as String?) ?? '',
    );
  }
  Future<String> materialize(FsNode node) async {
    if (node.location.isLocal) return node.location.path!;
    if (node.location.backend == FsBackend.transient) {
      final res = await _saf.invokeMapMethod<String, dynamic>(
        'readToCache',
        {'path': node.location.path, 'name': node.name},
      );
      return res!['path'] as String;
    }
    final res = await _saf.invokeMapMethod<String, dynamic>('readToCache', {
      ...node.location.toArgs(),
      'name': node.name,
    });
    if (res == null) throw SafException('io', 'Could not read ${node.name}');
    return res['path'] as String;
  }
  Future<Uint8List> readBytes(FsNode node, {int maxBytes = 32 * 1024 * 1024}) async {
    if (node.location.isLocal) {
      final file = File(node.location.path!);
      return file.readAsBytes();
    }
    return await _saf.invokeMethod<Uint8List>('readBytes', {
      ...node.location.toArgs(),
      'maxBytes': maxBytes,
      'name': node.name,
    }) ??
        Uint8List(0);
  }
  Future<void> writeBytes(FsNode node, List<int> bytes) async {
    if (node.location.isLocal) {
      await File(node.location.path!).writeAsBytes(bytes, flush: true);
      return;
    }
    await _saf.invokeMethod<bool>('writeBytes', {
      ...node.location.toArgs(),
      'bytes': bytes,
      'name': node.name,
    });
  }
  Future<void> writeFromPath(FsNode node, String sourcePath) async {
    if (node.location.isLocal) {
      await File(sourcePath).copy(node.location.path!);
      return;
    }
    await _saf.invokeMethod<bool>('writeFromPath', {
      ...node.location.toArgs(),
      'path': sourcePath,
      'name': node.name,
    });
  }
  Future<FsNode?> createFile(FsLocation parent, String name, String mime) async {
    if (parent.isLocal) {
      final file = File(p.join(parent.path!, name));
      await file.create(recursive: true);
      return FsNode.local(file);
    }
    final args = {...parent.toArgs(), 'name': name, 'mime': mime};
    final uri = await _saf.invokeMethod<String>('createFile', args);
    if (uri == null) return null;
    return FsNode(
      location: FsLocation.saf(treeUri: parent.treeUri!, docId: _docIdFrom(uri)),
      name: name,
      isDirectory: false,
      mime: mime,
      canWrite: true,
    );
  }
  Future<FsNode?> createDirectory(FsLocation parent, String name) async {
    if (parent.isLocal) {
      final dir = Directory(p.join(parent.path!, name));
      await dir.create(recursive: true);
      return FsNode(
        location: FsLocation.local(dir.path),
        name: name,
        isDirectory: true,
        mime: 'vnd.android.document/directory',
        canWrite: true,
      );
    }
    final uri = await _saf.invokeMethod<String>(
      'createDir',
      {...parent.toArgs(), 'name': name},
    );
    if (uri == null) return null;
    return FsNode(
      location: FsLocation.saf(treeUri: parent.treeUri!, docId: _docIdFrom(uri)),
      name: name,
      isDirectory: true,
      mime: 'vnd.android.document/directory',
      canWrite: true,
    );
  }
  String _docIdFrom(String uri) {
    final idx = uri.lastIndexOf("/document/");
    if (idx >= 0) return Uri.decodeComponent(uri.substring(idx + 10));
    return uri;
  }
  Future<bool> delete(FsNode node) async {
    if (node.location.isLocal) {
      if (node.isDirectory) {
        final dir = Directory(node.location.path!);
        if (dir.existsSync()) await dir.delete(recursive: true);
      } else {
        final f = File(node.location.path!);
        if (f.existsSync()) await f.delete();
      }
      return true;
    }
    return await _saf.invokeMethod<bool>('delete', node.location.toArgs()) ?? false;
  }
  Future<bool> rename(FsNode node, String newName) async {
    if (node.location.isLocal) {
      final target = p.join(p.dirname(node.location.path!), newName);
      if (node.isDirectory) {
        await Directory(node.location.path!).rename(target);
      } else {
        await File(node.location.path!).rename(target);
      }
      return true;
    }
    return await _saf.invokeMethod<bool>(
          'rename',
          {...node.location.toArgs(), 'newName': newName},
        ) ??
        false;
  }
  Future<FsNode?> copy(FsNode node, FsLocation destParent, String newName) async {
    if (destParent.isLocal) {
      final target = p.join(destParent.path!, newName);
      if (node.isDirectory) {
        await _copyDirectory(Directory(node.location.path!), Directory(target));
      } else {
        await File(node.location.path!).copy(target);
      }
      return FsNode.local(File(target));
    }
    final uri = await _saf.invokeMethod<String>('copy', {
      ...node.location.toArgs(),
      'name': node.name,
      'destTreeUri': destParent.treeUri,
      'destDocId': destParent.docId,
      'newName': newName,
    });
    if (uri == null) return null;
    return FsNode(
      location: FsLocation.saf(treeUri: destParent.treeUri!, docId: _docIdFrom(uri)),
      name: newName,
      isDirectory: false,
      mime: node.mime,
    );
  }
  Future<void> _copyDirectory(Directory from, Directory to) async {
    await to.create(recursive: true);
    for (final entity in from.listSync()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(to.path, name)));
      } else if (entity is File) {
        await entity.copy(p.join(to.path, name));
      }
    }
  }
  Future<Map<String, String>> appDirs() async {
    final res = await _saf.invokeMapMethod<String, dynamic>('appDirs') ?? {};
    return res.map((k, v) => MapEntry(k, v as String));
  }
  Future<void> shareLocal(String path, String mime) async {
    await _saf.invokeMethod<bool>('shareFile', {'path': path, 'mime': mime});
  }
  void listenInbox(void Function(List<Map<String, dynamic>> files) onFiles) {
    _inbox.setMethodCallHandler((call) async {
      if (call.method == 'onFiles') {
        final args = (call.arguments as List).cast<Map<dynamic, dynamic>>();
        onFiles(args.map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList());
      }
      return null;
    });
  }
}
