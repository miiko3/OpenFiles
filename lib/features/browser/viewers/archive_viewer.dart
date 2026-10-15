import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/file_kinds.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class ArchiveViewer extends StatefulWidget {
  const ArchiveViewer({super.key, required this.node});
  final FsNode node;
  @override
  State<ArchiveViewer> createState() => _ArchiveViewerState();
}
class _ArchiveViewerState extends State<ArchiveViewer> {
  void _goBack() => Navigator.of(context).pop();

  final _saf = SafService.instance;
  Archive? _archive;
  bool _loading = true;
  String? _error;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
      final decoded = ZipDecoder().decodeBytes(bytes);
      if (!mounted) return;
      setState(() {
        _archive = decoded;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) {
      return const LoadingOverlay(visible: true, message: 'Reading archive');
    }
    if (_error != null || _archive == null) {
      return FileLoadState(
        onBack: _goBack,
        child: EmptyState(
        icon: Icons.folder_zip_outlined,
        title: 'Cannot read ${widget.node.name}',
        message: _error,
          action: PillButton(
            label: 'Повторить',
            primary: true,
            onPressed: _load,
          ),
        ),
      );
    }
    final files = _archive!.files
        .where((f) => f.isFile)
        .where((f) => _query.isEmpty || f.name.toLowerCase().contains(_query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          color: c.bg,
          child: Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 36,
                iconSize: 16,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(Icons.folder_zip_outlined, size: 18),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  widget.node.name,
                  style: context.t.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${files.length} items', style: context.t.labelMedium),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Фильтр файлов',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              0,
              AppSpace.md,
              AppSpace.xl,
            ),
            itemCount: files.length,
            itemBuilder: (context, i) => _row(files[i], c),
          ),
        ),
      ],
    );
  }
  Widget _row(ArchiveFile file, AppColors c) {
    final kind = kindForName(file.name);
    final tint = kind.accent(context.scheme);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: AppRadius.sm,
        ),
        child: Icon(kind.icon, size: 18, color: tint),
      ),
      title: Text(
        file.name.split('/').last,
        overflow: TextOverflow.ellipsis,
        style: context.t.bodyMedium,
      ),
      subtitle: Text(
        '${file.name.contains('/') ? file.name.substring(0, file.name.lastIndexOf('/')) : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.t.labelSmall,
      ),
      trailing: Text(formatBytes(file.size), style: context.t.labelSmall),
      onTap: () => _open(file),
    );
  }
  Future<void> _open(ArchiveFile file) async {
    final bytes = Uint8List.fromList(file.content as List<int>);
    final kind = kindForName(file.name);
    final name = file.name.split('/').last;
    if (kind == FileKind.text || kind == FileKind.code || kind == FileKind.markdown) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextArchivePage(name: name, bytes: bytes),
        ),
      );
      return;
    }
    if (kind == FileKind.image) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageArchivePage(name: name, bytes: bytes),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HexArchivePage(name: name, bytes: bytes),
      ),
    );
  }
}
class TextArchivePage extends StatelessWidget {
  const TextArchivePage({super.key, required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
        ),
      ),
    );
  }
}
class ImageArchivePage extends StatelessWidget {
  const ImageArchivePage({super.key, required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
class HexArchivePage extends StatelessWidget {
  const HexArchivePage({super.key, required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = bytes.length ~/ 16 + (bytes.length % 16 == 0 ? 0 : 1);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          StatusBar(items: [
            Text(formatBytes(bytes.length)),
            const Spacer(),
            Text('${formatBytes(bytes.length)}'),
          ]),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpace.sm),
              itemCount: rows,
              itemBuilder: (context, r) {
                final start = r * 16;
                final end = start + 16 > bytes.length ? bytes.length : start + 16;
                final chunk = bytes.sublist(start, end);
                final hex = chunk
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ')
                    .padRight(47, ' ');
                final ascii = chunk
                    .map((b) => b >= 32 && b < 127 ? String.fromCharCode(b) : '.')
                    .join();
                return Text(
                  '${start.toRadixString(16).padLeft(8, '0')}  $hex  |$ascii|',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: c.text,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
