import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/fs_node.dart';
import '../../data/services/file_kinds.dart';
import '../../data/services/saf_service.dart';
import '../slides/slides_editor.dart';
import '../sheet/sheet_editor.dart';
import '../word/word_editor.dart';
import 'viewers/archive_viewer.dart';
import 'viewers/hex_viewer.dart';
import 'viewers/image_viewer.dart';
import 'viewers/media_viewer.dart';
import 'viewers/pdf_viewer.dart';
import 'viewers/csv_editor.dart';
import 'viewers/text_editor.dart';
class ViewerHost extends StatelessWidget {
  const ViewerHost({super.key, required this.node, this.allowEdit = true});
  final FsNode node;
  final bool allowEdit;
  @override
  Widget build(BuildContext context) {
    final kind = node.isDirectory ? FileKind.binary : kindForName(node.name);
    Widget screen;
    switch (kind) {
      case FileKind.word:
        screen = WordEditor(node: node);
      case FileKind.sheet:
        screen = SheetEditor(node: node);
      case FileKind.slides:
        screen = SlidesEditor(node: node);
      case FileKind.pdf:
        screen = PdfViewer(node: node, allowEdit: allowEdit);
      case FileKind.text:
      case FileKind.markdown:
      case FileKind.code:
        screen = TextEditor(
          node: node,
          readOnly: !allowEdit,
          previewable: kind == FileKind.markdown,
        );
      case FileKind.csv:
        screen = CsvEditor(node: node, readOnly: !allowEdit);
      case FileKind.image:
        screen = ImageViewer(node: node);
      case FileKind.audio:
      case FileKind.video:
        screen = MediaViewer(node: node, video: kind == FileKind.video);
      case FileKind.archive:
        screen = ArchiveViewer(node: node);
      default:
        screen = HexViewer(node: node);
    }
    return Scaffold(
      backgroundColor: context.c.bg,
      body: SafeArea(bottom: false, child: screen),
    );
  }
}
Future<String> stageFile(FsNode node) => SafService.instance.materialize(node);
String extOf(FsNode node) => node.extension.toUpperCase();
Future<void> shareNode(BuildContext context, FsNode node) async {
  final path = await stageFile(node);
  if (!context.mounted) return;
  await SafService.instance.shareLocal(path, node.mime);
}
Future<void> saveBytesTo(
  BuildContext context,
  FsNode node,
  List<int> bytes,
) async {
  await SafService.instance.writeBytes(node, bytes);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved ${node.name}')),
  );
}
Future<bool> writeTempFile(List<int> bytes, String name) async {
  final dir = Directory('${Directory.systemTemp.path}/openfiles');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return true;
}
