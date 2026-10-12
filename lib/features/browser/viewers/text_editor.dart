import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/providers/app_settings.dart';
import '../../../data/services/file_kinds.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class TextEditor extends StatefulWidget {
  const TextEditor({
    super.key,
    required this.node,
    this.readOnly = false,
    this.previewable = false,
    this.initialText,
  });
  final FsNode node;
  final bool readOnly;
  final bool previewable;
  final String? initialText;
  @override
  State<TextEditor> createState() => _TextEditorState();
}
class _TextEditorState extends State<TextEditor> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _saf = SafService.instance;
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  bool _wrap = true;
  bool _preview = false;
  bool _caseSensitive = false;
  int _matchCount = 0;
  int _fileBytes = 0;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _load();
  }
  void _onChanged() {
    final dirty = _controller.text != _originalText;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }
  String _originalText = '';
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String text;
      if (widget.initialText != null) {
        text = widget.initialText!;
      } else {
        final bytes = await _saf.readBytes(widget.node);
        _fileBytes = bytes.length;
        text = decodeText(bytes);
      }
      _originalText = text;
      _controller.text = text;
      _countMatches();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  static String _decodeUtf16(List<int> bytes) {
    final units = <int>[];
    final bigEndian = bytes.length >= 2 && bytes[0] == 0xFE;
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final hi = bigEndian ? bytes[i] : bytes[i + 1];
      final lo = bigEndian ? bytes[i + 1] : bytes[i];
      units.add((hi << 8) | lo);
    }
    return String.fromCharCodes(units);
  }
  static String decodeText(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
  Future<void> _save() async {
    try {
      await _saf.writeBytes(widget.node, utf8.encode(_controller.text));
      _originalText = _controller.text;
      if (!mounted) return;
      setState(() => _dirty = false);
      _toast('Saved ${widget.node.name}');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _saveAs() async {
    final name = await askFileName(context, widget.node.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      final target = await _saf.createFile(
        widget.node.location,
        name.trim(),
        mimeForName(name) ?? 'text/plain',
      );
      if (target == null) throw StateError('Cannot create $name');
      await _saf.writeBytes(target, utf8.encode(_controller.text));
      _originalText = _controller.text;
      if (!mounted) return;
      setState(() => _dirty = false);
      _toast('Saved as $name');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  void _countMatches() {
    final query = _findController.text;
    if (query.isEmpty) {
      _matchCount = 0;
      return;
    }
    final haystack = _caseSensitive ? _controller.text : _controller.text.toLowerCase();
    final needle = _caseSensitive ? query : query.toLowerCase();
    var count = 0;
    var index = haystack.indexOf(needle);
    while (index >= 0) {
      count++;
      index = haystack.indexOf(needle, index + needle.length);
    }
    _matchCount = count;
  }
  void _replaceOne() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final selection = _controller.selection;
    if (!selection.isValid) return;
    final raw = _controller.text;
    final compare = _caseSensitive ? raw : raw.toLowerCase();
    final needle = _caseSensitive ? query : query.toLowerCase();
    final start = selection.isCollapsed ? compare.indexOf(needle) : selection.start;
    if (start < 0) return;
    _controller.value = TextEditingValue(
      text: raw.replaceRange(start, start + needle.length, _replaceController.text),
      selection: TextSelection.collapsed(
        offset: start + _replaceController.text.length,
      ),
    );
    setState(_countMatches);
  }
  void _replaceAll() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final updated = _caseSensitive
        ? _controller.text.replaceAll(query, _replaceController.text)
        : _controller.text.replaceAll(
            RegExp(RegExp.escape(query), caseSensitive: false),
            _replaceController.text,
          );
    _controller.text = updated;
    setState(_countMatches);
  }
  void _jumpToMatch() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final compare = _caseSensitive ? _controller.text : _controller.text.toLowerCase();
    final needle = _caseSensitive ? query : query.toLowerCase();
    var index = compare.indexOf(needle, _controller.selection.baseOffset + 1);
    if (index < 0) index = compare.indexOf(needle);
    if (index < 0) return;
    _controller.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + needle.length,
    );
    setState(_countMatches);
  }
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: const Text('Сохранить правки перед выходом?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Не сохранять'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              _save();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingOverlay(visible: true, message: 'Opening');
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    final c = context.c;
    final settings = context.watch<AppSettings>();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) Navigator.of(context).pop();
      },
      child: Column(
        children: [
          _topBar(c),
          if (widget.previewable && _preview) _previewPane(c),
          Expanded(child: _editorPane(c, settings)),
          _statusBar(c),
        ],
      ),
    );
  }
  Widget _topBar(AppColors c) {
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
            onPressed: () async {
              if (await _confirmLeave() && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: AppSpace.sm),
          Icon(kind.icon, size: 18, color: kind.accent(context.scheme)),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              widget.node.name,
              style: context.t.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_dirty)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
          RoundIconButton(
            icon: Icons.search_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Поиск и замена',
            onPressed: _showFind,
          ),
          if (widget.previewable)
            RoundIconButton(
              icon: _preview ? Icons.edit_note_rounded : Icons.visibility_outlined,
              size: 36,
              iconSize: 18,
              active: _preview,
              tooltip: _preview ? 'Edit' : 'Preview',
              onPressed: () => setState(() => _preview = !_preview),
            ),
          RoundIconButton(
            icon: Icons.save_outlined,
            size: 36,
            iconSize: 18,
            tooltip: 'Save',
            onPressed: widget.readOnly || !_dirty ? null : _save,
          ),
          RoundIconButton(
            icon: Icons.more_vert_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'More',
            onPressed: () => _showMenu(c),
          ),
        ],
      ),
    );
  }
  Future<void> _showFind() async {
    await showRoundedSheet<void>(
      context,
      title: 'Поиск и замена',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _findController,
            decoration: const InputDecoration(
              labelText: 'Find',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
            onChanged: (_) => setState(_countMatches),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _replaceController,
            decoration: const InputDecoration(
              labelText: 'Replace with',
              prefixIcon: Icon(Icons.swap_horiz_rounded, size: 18),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Text('$_matchCount matches', style: context.t.bodySmall),
              const Spacer(),
              FilterChip(
                label: const Text('Aa'),
                selected: _caseSensitive,
                onSelected: (v) {
                  _caseSensitive = v;
                  setState(_countMatches);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              PillButton(label: 'Вперёд', icon: Icons.keyboard_arrow_down, onPressed: _jumpToMatch),
              PillButton(label: 'Replace', onPressed: _replaceOne),
              PillButton(label: 'Заменить всё', primary: true, onPressed: _replaceAll),
            ],
          ),
        ],
      ),
    );
  }
  Future<void> _showMenu(AppColors c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_as_outlined),
              title: const Text('Сохранить как'),
              onTap: () {
                Navigator.of(ctx).pop();
                _saveAs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.wrap_text_rounded),
              title: Text(_wrap ? 'Disable line wrap' : 'Enable line wrap'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _wrap = !_wrap);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Поделиться'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final path = await _saf.materialize(widget.node);
                await _saf.shareLocal(path, widget.node.mime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Статистика'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showStats();
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  void _showStats() {
    final text = _controller.text;
    final words = RegExp(r"\S+").allMatches(text).length;
    final lines = '\n'.allMatches(text).length + 1;
    showRoundedSheet<void>(
      context,
      title: 'Статистика',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat('Слов', '$words'),
          _stat('Символов', '${text.length}'),
          _stat('Строк', '$lines'),
          _stat('File size', '$_fileBytes bytes'),
        ],
      ),
    );
  }
  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(k, style: context.t.bodySmall)),
            Text(v, style: context.t.bodyMedium),
          ],
        ),
      );
  Widget _editorPane(AppColors c, AppSettings settings) {
    final isCode = kindForName(widget.node.name) == FileKind.code;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpace.md),
          child: TextField(
            controller: _controller,
            readOnly: widget.readOnly,
            maxLines: null,
            minLines: null,
            expands: false,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            autocorrect: !isCode,
            enableSuggestions: !isCode,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            cursorWidth: 2,
            cursorColor: c.primary,
            style: TextStyle(
              fontSize: 14 * settings.textScale,
              height: 1.6,
              color: c.text,
              fontFamily: isCode ? 'monospace' : null,
            ),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
  Widget _previewPane(AppColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpace.md,
        0,
        AppSpace.md,
        AppSpace.md,
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: c.border),
      ),
      child: SingleChildScrollView(
        child: MarkdownLite(data: _controller.text),
      ),
    );
  }
  Widget _statusBar(AppColors c) {
    return StatusBar(
      items: [
        Text('${_controller.text.length} chars'),
        const Spacer(),
        Text('${'\n'.allMatches(_controller.text).length + 1} lines'),
        const Spacer(),
        Text(widget.node.extension.toUpperCase()),
      ],
    );
  }
}
class MarkdownLite extends StatelessWidget {
  const MarkdownLite({super.key, required this.data});
  final String data;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final blocks = <Widget>[];
    final lines = data.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        i++;
        continue;
      }
      if (trimmed.startsWith('```')) {
        final buffer = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buffer.add(lines[i]);
          i++;
        }
        i++;
        blocks.add(_code(context, buffer.join('\n')));
        continue;
      }
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = 26.0 - (level - 1) * 2.5;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: level <= 2 ? 14 : 10, bottom: 6),
            child: Text(
              heading.group(2)!,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: c.text,
              ),
            ),
          ),
        );
        i++;
        continue;
      }
      if (RegExp(r'^\s*([-*+]|\d+\.)\s+').hasMatch(trimmed)) {
        final items = <String>[];
        var ordered = RegExp(r'^\s*\d+\.\s').hasMatch(trimmed);
        while (i < lines.length &&
            RegExp(r'^\s*([-*+]|\d+\.)\s+').hasMatch(lines[i])) {
          items.add(lines[i].replaceFirst(RegExp(r'^\s*([-*+]|\d+\.)\s+'), ''));
          i++;
        }
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (var n = 0; n < items.length; n++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            ordered ? '${n + 1}.' : '•',
                            style: context.t.bodyLarge?.copyWith(color: c.primary),
                          ),
                        ),
                        Expanded(child: _inline(context, items[n])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
        continue;
      }
      if (RegExp(r'^\s*(---|\*\*\*|___)\s*$').hasMatch(trimmed)) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: c.border),
          ),
        );
        i++;
        continue;
      }
      final buffer = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('#') &&
          !lines[i].startsWith('```') &&
          !RegExp(r'^\s*([-*+]|\d+\.)\s').hasMatch(lines[i])) {
        buffer.add(lines[i]);
        i++;
      }
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _inline(context, buffer.join(' ')),
        ),
      );
    }
    if (blocks.isEmpty) {
      return Text('Нечего показывать', style: context.t.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
  Widget _code(BuildContext context, String source) {
    final c = context.c;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: AppRadius.md,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          source,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: c.text,
          ),
        ),
      ),
    );
  }
  Widget _inline(BuildContext context, String source) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`)');
    var index = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start > index) {
        spans.add(TextSpan(text: source.substring(index, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              color: context.c.secondary,
              backgroundColor: context.c.surfaceAlt,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      index = match.end;
    }
    if (index < source.length) {
      spans.add(TextSpan(text: source.substring(index)));
    }
    return Text.rich(
      TextSpan(style: context.t.bodyLarge, children: spans),
    );
  }
}
Future<String?> askFileName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Сохранить как'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'name.txt'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
