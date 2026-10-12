import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/file_kinds.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class HexViewer extends StatefulWidget {
  const HexViewer({super.key, required this.node});
  final FsNode node;
  @override
  State<HexViewer> createState() => _HexViewerState();
}
class _HexViewerState extends State<HexViewer> {
  final _saf = SafService.instance;
  final _scroll = ScrollController();
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  int _pageSize = 512;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(
        widget.node,
        maxBytes: 64 * 1024 * 1024,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
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
    if (_loading) return const LoadingOverlay(visible: true, message: 'Reading file');
    if (_error != null || _bytes == null) {
      return EmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: 'Cannot read ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    final bytes = _bytes!;
    final totalPages = (bytes.length ~/ _pageSize) + 1;
    final start = _page * _pageSize;
    final end = start + _pageSize > bytes.length ? bytes.length : start + _pageSize;
    final chunk = bytes.sublist(start, end);
    final rows = chunk.length ~/ 16 + (chunk.length % 16 == 0 ? 0 : 1);
    return Column(
      children: [
        _bar(c, bytes),
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpace.sm),
              itemCount: rows,
              itemBuilder: (context, r) {
                final rowStart = r * 16;
                final rowEnd = rowStart + 16 > chunk.length ? chunk.length : rowStart + 16;
                final line = chunk.sublist(rowStart, rowEnd);
                final hex = line
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ')
                    .padRight(47, ' ');
                final ascii = line
                    .map((b) => b >= 32 && b < 127 ? String.fromCharCode(b) : '.')
                    .join();
                return GestureDetector(
                  onTap: () => _copyRange(bytes, start + rowStart, rowEnd - rowStart),
                  child: Text(
                    '${(start + rowStart).toRadixString(16).padLeft(8, '0')}  $hex  |$ascii|',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.55,
                      color: c.text,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        StatusBar(
          items: [
            Text('${formatBytes(bytes.length)}'),
            const Spacer(),
            Text('Page ${_page + 1} / $totalPages'),
            const SizedBox(width: AppSpace.md),
            RoundIconButton(
              icon: Icons.chevron_left_rounded,
              size: 26,
              iconSize: 18,
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
            ),
            RoundIconButton(
              icon: Icons.chevron_right_rounded,
              size: 26,
              iconSize: 18,
              onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }
  void _copyRange(Uint8List bytes, int offset, int length) {
    final slice = bytes.sublist(offset, offset + length);
    Clipboard.setData(ClipboardData(text: slice.join(' ')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Строка скопирована')),
    );
  }
  Widget _bar(AppColors c, Uint8List bytes) {
    final kind = kindForName(widget.node.name);
    return Container(
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
          Icon(kind.icon, size: 18, color: kind.accent(context.scheme)),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.node.name,
                  style: context.t.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${formatBytes(bytes.length)}', style: context.t.labelSmall),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.search_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Поиск по байтам',
            onPressed: () => _search(bytes, c),
          ),
          RoundIconButton(
            icon: Icons.ios_share_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Поделиться',
            onPressed: () async {
              final path = await _saf.materialize(widget.node);
              if (!context.mounted) return;
              await _saf.shareLocal(path, widget.node.mime);
            },
          ),
        ],
      ),
    );
  }
  Future<void> _search(Uint8List bytes, AppColors c) async {
    final controller = TextEditingController();
    await showRoundedSheet<void>(
      context,
      title: 'Поиск по байтам',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'ASCII or hex bytes'),
          ),
          const SizedBox(height: AppSpace.md),
          PillButton(
            label: 'Find',
            primary: true,
            onPressed: () {
              final term = controller.text.trim();
              if (term.isEmpty) return;
              final index = _find(bytes, term);
              Navigator.of(context).pop();
              if (index < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Not found in ${formatBytes(bytes.length)}')),
                );
                return;
              }
              final page = index ~/ _pageSize;
              setState(() => _page = page);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Found at 0x${index.toRadixString(16)}')),
              );
            },
          ),
        ],
      ),
    );
  }
  int _find(Uint8List bytes, String term) {
    final asHex = RegExp(r'^[0-9a-fA-F ]+$').hasMatch(term);
    if (asHex) {
      final hex = term.replaceAll(' ', '');
      if (hex.length.isOdd) return -1;
      final needle = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        needle.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return _searchBytes(bytes, needle);
    }
    return _searchBytes(bytes, term.codeUnits);
  }
  int _searchBytes(Uint8List haystack, List<int> needle) {
    if (needle.isEmpty || needle.length > haystack.length) return -1;
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      var hit = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          hit = false;
          break;
        }
      }
      if (hit) return i;
    }
    return -1;
  }
}