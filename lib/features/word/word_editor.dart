import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/fs_node.dart';
import '../../data/providers/app_settings.dart';
import '../../data/services/saf_service.dart';
import '../../widgets/common.dart';
import 'docx_codec.dart';
class WordEditor extends StatefulWidget {
  const WordEditor({super.key, required this.node});
  final FsNode node;
  @override
  State<WordEditor> createState() => _WordEditorState();
}
class _WordEditorState extends State<WordEditor> {
  final _saf = SafService.instance;
  final _pageScroll = ScrollController();
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final List<WordDocument> _undo = [];
  final List<WordDocument> _redo = [];
  WordDocument _doc = WordDocument();
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  int _focused = -1;
  double _zoom = 1.0;
  bool _showMarks = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _pageScroll.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
      final doc = await DocxCodec.load(bytes);
      _doc = doc;
      _zoom = context.read<AppSettings>().defaultZoom;
      _showMarks = context.read<AppSettings>().showFormattingMarks;
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
  void _pushUndo() {
    _undo.add(_doc.clone());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }
  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_doc.clone());
    setState(() => _doc = _undo.removeLast());
  }
  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_doc.clone());
    setState(() => _doc = _redo.removeLast());
  }
  TextEditingController _controllerFor(int index) {
    return _controllers.putIfAbsent(index, () {
      final block = _doc.blocks[index];
      final text = block is DocTextBlock ? block.paragraph.plainText : '';
      return TextEditingController(text: text);
    });
  }
  FocusNode _focusFor(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode());
  void _syncParagraph(int index, String text) {
    final block = _doc.blocks[index];
    if (block is! DocTextBlock) return;
    if (block.paragraph.plainText == text) return;
    final caret = _controllerFor(index).selection.baseOffset;
    final style = block.paragraph.style;
    final inherited = _inheritedRunStyle(index);
    final lines = text.split('\n');
    block.paragraph.runs = [
      for (var i = 0; i < lines.length; i++)
        DocRun(lines[i], inherited),
      if (lines.isEmpty) DocRun('', inherited),
    ];
    block.paragraph.style = style;
    setState(() => _dirty = true);
    if (caret >= 0) {
      final offset = caret.clamp(0, text.length);
      _controllerFor(index).selection =
          TextSelection.collapsed(offset: offset);
    }
  }
  RunStyle _inheritedRunStyle(int index) {
    final block = _doc.blocks[index];
    if (block is! DocTextBlock) return const RunStyle();
    if (block.paragraph.runs.isNotEmpty) return block.paragraph.runs.first.style;
    for (var i = index - 1; i >= 0; i--) {
      final previous = _doc.blocks[i];
      if (previous is DocTextBlock && previous.paragraph.runs.isNotEmpty) {
        return previous.paragraph.runs.first.style;
      }
    }
    return const RunStyle();
  }
  void _insertParagraphAfter(int index, {DocList? list, int? headingLevel}) {
    _pushUndo();
    final current = _doc.blocks[index];
    final base = current is DocTextBlock ? current.paragraph.style : const ParaStyle();
    final nextStyle = ParaStyle(
      align: base.align,
      list: list ?? (base.list == DocList.none ? DocList.none : base.list),
      listLevel: base.listLevel,
      headingLevel: headingLevel,
      spaceBefore: base.spaceBefore,
      spaceAfter: base.spaceAfter,
      lineHeight: base.lineHeight,
    );
    _doc.blocks.insert(
      index + 1,
      DocTextBlock(DocParagraph(runs: [const DocRun('')], style: nextStyle)),
    );
    setState(() => _dirty = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFor(index + 1).requestFocus();
    });
  }
  void _splitParagraph(int index, int caret) {
    final controller = _controllerFor(index);
    final text = controller.text;
    final block = _doc.blocks[index] as DocTextBlock;
    final head = text.substring(0, caret);
    final tail = text.substring(caret);
    controller.text = head;
    _syncParagraph(index, head);
    _insertParagraphAfter(index, list: block.paragraph.style.list);
    final next = _doc.blocks[index + 1] as DocTextBlock;
    next.paragraph.runs = [DocRun(tail, _inheritedRunStyle(index))];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nextController = _controllerFor(index + 1);
      nextController.text = tail;
      _focusFor(index + 1).requestFocus();
      nextController.selection = TextSelection.collapsed(offset: 0);
    });
  }
  KeyEventResult _handleParagraphKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      final controller = _controllerFor(index);
      final sel = controller.selection;
      if (!sel.isValid) return KeyEventResult.ignored;
      final text = controller.text;
      final caret = sel.start;
      if (text.contains('\n')) return KeyEventResult.ignored;
      _splitParagraph(index, caret);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      final controller = _controllerFor(index);
      final sel = controller.selection;
      if (!sel.isValid || sel.start != 0 || sel.end != 0) {
        return KeyEventResult.ignored;
      }
      if (index == 0) return KeyEventResult.ignored;
      _mergeWithPrevious(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _mergeWithPrevious(int index) {
    if (index == 0) return;
    final previous = _doc.blocks[index - 1];
    if (previous is! DocTextBlock) return;
    _pushUndo();
    final current = _doc.blocks[index];
    final tail = current is DocTextBlock ? current.paragraph.plainText : '';
    final head = previous.paragraph.plainText;
    final merged = head + tail;
    previous.paragraph.runs = [DocRun(merged, _inheritedRunStyle(index - 1))];
    _doc.blocks.removeAt(index);
    _controllers.remove(index)?.dispose();
    _focusNodes.remove(index)?.dispose();
    setState(() => _dirty = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _controllerFor(index - 1);
      c.text = merged;
      c.selection = TextSelection.collapsed(offset: head.length);
      _focusFor(index - 1).requestFocus();
    });
  }
  void _deleteBlock(int index) {
    _pushUndo();
    _doc.blocks.removeAt(index);
    _controllers.remove(index)?.dispose();
    _focusNodes.remove(index)?.dispose();
    setState(() => _dirty = true);
  }
  void _applyParaStyle(ParaStyle Function(ParaStyle) transform) {
    final index = _focused;
    if (index < 0 || index >= _doc.blocks.length) return;
    final block = _doc.blocks[index];
    if (block is! DocTextBlock) return;
    _pushUndo();
    block.paragraph.style = transform(block.paragraph.style);
    setState(() => _dirty = true);
  }
  void _applyRunStyle(RunStyle Function(RunStyle) transform) {
    final index = _focused;
    if (index < 0 || index >= _doc.blocks.length) return;
    final block = _doc.blocks[index];
    if (block is! DocTextBlock) return;
    _pushUndo();
    final controller = _controllerFor(index);
    final selection = controller.selection;
    final runs = block.paragraph.runs;
    if (!selection.isValid || selection.isCollapsed || runs.isEmpty) {
      final newStyle = transform(runs.first.style);
      block.paragraph.runs = [
        for (final run in runs) DocRun(run.text, newStyle),
      ];
    } else {
      final from = selection.start.clamp(0, controller.text.length);
      final to = selection.end.clamp(0, controller.text.length);
      var cursor = 0;
      block.paragraph.runs = [
        for (final run in runs) ..._splitRun(run, from, to, transform, () => cursor += run.text.length),
      ];
    }
    setState(() => _dirty = true);
  }
  List<DocRun> _splitRun(
    DocRun run,
    int from,
    int to,
    RunStyle Function(RunStyle) transform,
    int Function() advance,
  ) {
    final text = run.text;
    final runStart = advance();
    final runEnd = runStart + text.length;
    if (to <= runStart || from >= runEnd) return [DocRun(text, run.style)];
    final localFrom = (from - runStart).clamp(0, text.length);
    final localTo = (to - runStart).clamp(0, text.length);
    if (localFrom == 0 && localTo == text.length) {
      return [DocRun(text, transform(run.style))];
    }
    return [
      if (localFrom > 0) DocRun(text.substring(0, localFrom), run.style),
      DocRun(
        text.substring(localFrom, localTo),
        transform(run.style),
      ),
      if (localTo < text.length) DocRun(text.substring(localTo), run.style),
    ];
  }
  void _applyHeading(int level) {
    _applyParaStyle(
      (s) => s.headingLevel == level
          ? ParaStyle(
              align: s.align,
              spaceBefore: s.spaceBefore,
              spaceAfter: s.spaceAfter,
              lineHeight: s.lineHeight,
            )
          : ParaStyle(
              align: s.align,
              spaceBefore: s.spaceBefore,
              spaceAfter: s.spaceAfter,
              lineHeight: s.lineHeight,
              headingLevel: level,
            ),
    );
  }
  void _insertTable() {
    _pushUndo();
    _doc.blocks.add(
      DocTableBlock(
        DocTable([
          for (var r = 0; r < 3; r++)
            DocTableRow([
              for (var c = 0; c < 3; c++) DocTableCell([DocParagraph()]),
            ]),
        ]),
      ),
    );
    setState(() => _dirty = true);
  }
  void _insertRule() {
    _pushUndo();
    _doc.blocks.add(
      DocTextBlock(
        DocParagraph(
          runs: [DocRun('', const RunStyle(fontSize: 4))],
          style: const ParaStyle(
            spaceBefore: 6,
            spaceAfter: 6,
            shading: 0xFFD8CFC2,
          ),
        ),
      ),
    );
    setState(() => _dirty = true);
  }
  void _insertPageBreak() {
    _pushUndo();
    _doc.blocks.add(DocBreakBlock());
    setState(() => _dirty = true);
  }
  Future<void> _save() async {
    try {
      final bytes = await DocxCodec.save(_doc);
      await _saf.writeBytes(widget.node, bytes);
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
  Future<void> _exportPdf() async {
    try {
      _toast('Generating PDF');
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: '${widget.node.name}.pdf');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final setup = _doc.pageSetup;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          setup.pageWidthPt,
          setup.pageHeightPt,
          marginAll: 0,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: setup.marginTopPt),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: setup.marginLeftPt,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final block in _doc.blocks)
                    switch (block) {
                      DocTextBlock(:final paragraph) => pw.Padding(
                          padding: pw.EdgeInsets.only(
                            top: paragraph.style.spaceBefore ?? 0,
                            bottom: paragraph.style.spaceAfter ?? 4,
                            left: paragraph.style.indentLeft ?? 0,
                          ),
                          child: pw.Text(
                            paragraph.plainText,
                            textAlign: switch (paragraph.style.align) {
                              DocAlign.center => pw.TextAlign.center,
                              DocAlign.right => pw.TextAlign.right,
                              DocAlign.justify => pw.TextAlign.justify,
                              _ => pw.TextAlign.left,
                            },
                            style: pw.TextStyle(
                              fontSize: paragraph.runs.isEmpty
                                  ? 11
                                  : paragraph.runs.first.style.fontSize ?? 11,
                              fontWeight: paragraph.runs.isNotEmpty &&
                                      paragraph.runs.first.style.bold
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                              fontStyle: paragraph.runs.isNotEmpty &&
                                      paragraph.runs.first.style.italic
                                  ? pw.FontStyle.italic
                                  : pw.FontStyle.normal,
                              decoration: paragraph.runs.isNotEmpty &&
                                      paragraph.runs.first.style.underline
                                  ? pw.TextDecoration.underline
                                  : pw.TextDecoration.none,
                              color: paragraph.runs.isNotEmpty &&
                                      paragraph.runs.first.style.color != null
                                  ? PdfColor.fromInt(
                                      paragraph.runs.first.style.color!,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      DocTableBlock(:final table) => pw.Table(
                          border: pw.TableBorder.all(
                            color: PdfColors.grey300,
                            width: 0.5,
                          ),
                          children: [
                            for (final row in table.rows)
                              pw.TableRow(
                                children: [
                                  for (final cell in row.cells)
                                    pw.Expanded(
                                      child: pw.Padding(
                                        padding: const pw.EdgeInsets.all(3),
                                        child: pw.Text(cell.plainText),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      DocBreakBlock() => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10)),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
  Future<void> _findReplace() async {
    await showRoundedSheet<void>(
      context,
      title: 'Поиск и замена',
      child: _FindSheet(
        onFind: (term) {
          setState(() => _searchTerm = term);
          _highlightFirst(term);
        },
        onReplace: (from, to) {
          _replaceAll(from, to);
        },
      ),
    );
  }
  String _searchTerm = '';
  void _highlightFirst(String term) {
    if (term.isEmpty) return;
    for (var i = 0; i < _doc.blocks.length; i++) {
      final block = _doc.blocks[i];
      if (block is! DocTextBlock) continue;
      if (!block.paragraph.plainText.toLowerCase().contains(term.toLowerCase())) {
        continue;
      }
      _focusFor(i).requestFocus();
      _pageScroll.animateTo(
        (i * 90.0 * _zoom).clamp(0, _pageScroll.position.maxScrollExtent),
        duration: AppDuration.normal,
        curve: AppDuration.curve,
      );
      return;
    }
  }
  void _replaceAll(String from, String to) {
    if (from.isEmpty) return;
    _pushUndo();
    var count = 0;
    for (final block in _doc.blocks) {
      if (block is! DocTextBlock) continue;
      final text = block.paragraph.plainText;
      if (!text.toLowerCase().contains(from.toLowerCase())) continue;
      final updated = text.replaceAll(from, to);
      count += RegExp(RegExp.escape(from), caseSensitive: false).allMatches(text).length;
      block.paragraph.runs = [DocRun(updated, _inheritedRunStyle(_doc.blocks.indexOf(block)))];
      final index = _doc.blocks.indexOf(block);
      _controllers.remove(index)?.dispose();
    }
    setState(() => _dirty = true);
    _toast('Replaced $count occurrences');
  }
  void _showStats() {
    showRoundedSheet<void>(
      context,
      title: 'Подсчёт слов',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat('Слов', '${_doc.wordCount}'),
          _stat('Символов', '${_doc.characterCount}'),
          _stat('Абзацев', '${_doc.paragraphCount}'),
          _stat('Таблиц', '${_doc.tableCount}'),
          _stat('Blocks', '${_doc.blocks.length}'),
          _stat(
            'Reading time',
            '${(_doc.wordCount / 180).ceil()} min',
          ),
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
  Future<void> _pageSetup() async {
    final result = await showRoundedSheet<DocPageSetup>(
      context,
      title: 'Параметры страницы',
      child: _PageSetupForm(initial: _doc.pageSetup),
    );
    if (result == null) return;
    _pushUndo();
    setState(() {
      _doc.pageSetup = result;
      _dirty = true;
    });
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) return const LoadingOverlay(visible: true, message: 'Opening');
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    return Column(
      children: [
        _bar(c),
        Expanded(child: _canvas(c)),
        _toolbar(c),
        StatusBar(
          items: [
            Text('${_doc.wordCount} words'),
            const Spacer(),
            Text('Page ${_pageNumber(width: 420)}'),
            const Spacer(),
            Text('${(_doc.zoomSafe * 100).round()}%'),
          ],
        ),
      ],
    );
  }
  int _pageNumber({required double width}) {
    final setup = _doc.pageSetup;
    final perPage = (setup.pageHeightPt - setup.marginTopPt - setup.marginBottomPt) ~/ 26;
    final breakCount = _doc.blocks.whereType<DocBreakBlock>().length;
    return perPage <= 0 ? breakCount + 1 : (breakCount + 1).clamp(1, 9999);
  }
  Widget _bar(AppColors c) {
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
          const Icon(Icons.article_outlined, size: 18),
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
            tooltip: 'Find',
            onPressed: _findReplace,
          ),
          RoundIconButton(
            icon: Icons.picture_as_pdf_outlined,
            size: 36,
            iconSize: 18,
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
          RoundIconButton(
            icon: Icons.save_outlined,
            size: 36,
            iconSize: 18,
            tooltip: 'Save',
            onPressed: _dirty ? _save : null,
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
              leading: const Icon(Icons.crop_portrait_rounded),
              title: const Text('Параметры страницы'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pageSetup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined_rounded),
              title: const Text('Подсчёт слов'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showStats();
              },
            ),
            ListTile(
              leading: Icon(
                _showMarks
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(_showMarks ? 'Hide marks' : 'Show marks'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _showMarks = !_showMarks);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Поделиться'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final path = await _saf.materialize(widget.node);
                if (!context.mounted) return;
                await _saf.shareLocal(path, widget.node.mime);
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  Widget _canvas(AppColors c) {
    final setup = _doc.pageSetup;
    final baseWidth = context.read<AppSettings>().pageWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - AppSpace.md * 2;
        final fit = baseWidth > available ? available : baseWidth;
        final width = (fit * _zoom).clamp(240.0, 1400.0);
        final scale = width / setup.pageWidthPt;
        final height = setup.pageHeightPt * scale;
        final page = Container(
          width: width,
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            color: c.brightness == Brightness.dark
                ? const Color(0xFF23201D)
                : Colors.white,
            borderRadius: AppRadius.sm,
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: setup.marginLeftPt * scale,
            vertical: setup.marginTopPt * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _doc.blocks.length; i++)
                _block(i, c, scale),
            ],
          ),
        );
        return Container(
          color: c.canvas,
          child: Scrollbar(
            controller: _pageScroll,
            child: SingleChildScrollView(
              controller: _pageScroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.md,
                AppSpace.md,
                AppSpace.xl,
              ),
              child: Center(child: page),
            ),
          ),
        );
      },
    );
  }
  Widget _block(int index, AppColors c, double scale) {
    final block = _doc.blocks[index];
    switch (block) {
      case DocBreakBlock():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Row(
            children: [
              Expanded(child: Divider(color: c.danger.withValues(alpha: 0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                child: Text('page break', style: context.t.labelSmall),
              ),
              Expanded(child: Divider(color: c.danger.withValues(alpha: 0.5))),
            ],
          ),
        );
      case DocTableBlock(:final table):
        return _tableBlock(index, table, c);
      case DocTextBlock(:final paragraph):
        return _textBlock(index, paragraph, c, scale);
    }
  }
  Widget _textBlock(int index, DocParagraph paragraph, AppColors c, double scale) {
    final style = paragraph.style;
    final headingSize = style.headingLevel == null
        ? null
        : (26.0 - (style.headingLevel! * 3)).clamp(14.0, 26.0);
    final controller = _controllerFor(index);
    final focus = _focusFor(index);
    final textField = TextField(
      controller: controller,
      focusNode: focus,
      maxLines: null,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      cursorColor: c.primary,
      onTap: () => _setFocused(index),
      onChanged: (value) => _syncParagraph(index, value),
      onSubmitted: null,
      style: TextStyle(
        fontSize: (headingSize ?? 15) * scale,
        height: style.lineHeight ?? 1.5,
        fontWeight: headingSize != null ? FontWeight.w700 : FontWeight.w400,
        fontFamily: paragraph.runs.isEmpty
            ? null
            : paragraph.runs.first.style.fontFamily,
        color: c.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: '',
      ),
    );
    return Focus(
      onKeyEvent: (node, event) => _handleParagraphKey(index, event),
      child: GestureDetector(
        onDoubleTap: () => _insertParagraphAfter(index),
        child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: (style.indentLeft ?? 0) * scale +
              (style.list == DocList.none ? 0 : 18 * scale),
          right: (style.indentRight ?? 0) * scale,
          top: (style.spaceBefore ?? 0) * scale,
          bottom: (style.spaceAfter ?? 4) * scale,
        ),
        decoration: BoxDecoration(
          color: _searchTerm.isNotEmpty &&
                  paragraph.plainText
                      .toLowerCase()
                      .contains(_searchTerm.toLowerCase())
              ? c.warning.withValues(alpha: 0.16)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (style.list != DocList.none)
              SizedBox(
                width: 22 * scale,
                child: Text(
                  style.list == DocList.bullet
                      ? '•'
                      : '${index + 1}.',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: _wrapMarks(paragraph, c, textField),
            ),
          ],
        ),
        ),
      ),
    );
  }
  Widget _wrapMarks(DocParagraph paragraph, AppColors c, Widget child) {
    if (!_showMarks || paragraph.runs.length < 2) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final run in paragraph.runs.where((r) => r.text.isNotEmpty))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${run.style.bold ? 'B' : ''}'
                    '${run.style.italic ? 'I' : ''}'
                    '${run.style.underline ? 'U' : ''}'
                    '${run.style.fontSize?.round() ?? ''}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF8C8075)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _tableBlock(int index, DocTable table, AppColors c) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Table(
        border: TableBorder.all(color: c.border, width: 1),
        children: [
          for (final row in table.rows)
            TableRow(
              children: [
                for (final cell in row.cells)
                  InkWell(
                    onTap: () => _editTableCell(index, cell),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 90, minHeight: 36),
                      padding: const EdgeInsets.all(AppSpace.sm),
                      color: cell.fill == null
                          ? null
                          : Color(cell.fill! & 0xFFFFFF),
                      child: Text(
                        cell.plainText,
                        style: context.t.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
  Future<void> _editTableCell(int tableIndex, DocTableCell cell) async {
    final controller = TextEditingController(text: cell.plainText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ячейка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    _pushUndo();
    setState(() {
      cell.paragraphs = [DocParagraph(runs: [DocRun(result)])];
      _dirty = true;
    });
  }
  void _setFocused(int index) {
    if (_focused == index) return;
    setState(() => _focused = index);
  }
  Widget _toolbar(AppColors c) {
    final index = _focused;
    final block = index >= 0 && index < _doc.blocks.length
        ? _doc.blocks[index]
        : null;
    final para = block is DocTextBlock ? block.paragraph.style : const ParaStyle();
    final run = block is DocTextBlock && block.paragraph.runs.isNotEmpty
        ? block.paragraph.runs.first.style
        : const RunStyle();
    final enabled = block is DocTextBlock;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            RoundIconButton(
              icon: Icons.undo_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Undo',
              onPressed: _undo.isEmpty ? null : _undoEdit,
            ),
            RoundIconButton(
              icon: Icons.redo_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Redo',
              onPressed: _redo.isEmpty ? null : _redoEdit,
            ),
            _divider(c),
            RoundIconButton(
              icon: Icons.format_bold_rounded,
              size: 36,
              iconSize: 18,
              active: run.bold,
              tooltip: 'Bold',
              onPressed: enabled
                  ? () => _applyRunStyle((s) => _flip(s, bold: true))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_italic_rounded,
              size: 36,
              iconSize: 18,
              active: run.italic,
              tooltip: 'Italic',
              onPressed: enabled
                  ? () => _applyRunStyle((s) => _flip(s, italic: true))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_underlined_rounded,
              size: 36,
              iconSize: 18,
              active: run.underline,
              tooltip: 'Underline',
              onPressed: enabled
                  ? () => _applyRunStyle((s) => _flip(s, underline: true))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.strikethrough_s_rounded,
              size: 36,
              iconSize: 18,
              active: run.strikethrough,
              tooltip: 'Strike',
              onPressed: enabled
                  ? () => _applyRunStyle((s) => _flip(s, strikethrough: true))
                  : null,
            ),
            _divider(c),
            _fontSize(c, enabled),
            _divider(c),
            RoundIconButton(
              icon: Icons.format_align_left_rounded,
              size: 36,
              iconSize: 18,
              active: para.align == DocAlign.left,
              tooltip: 'По левому краю',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: DocAlign.left,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        lineHeight: s.lineHeight,
                        indentLeft: s.indentLeft,
                        indentRight: s.indentRight,
                        headingLevel: s.headingLevel,
                        list: s.list,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_align_center_rounded,
              size: 36,
              iconSize: 18,
              active: para.align == DocAlign.center,
              tooltip: 'Center',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: DocAlign.center,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        lineHeight: s.lineHeight,
                        headingLevel: s.headingLevel,
                        list: s.list,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_align_right_rounded,
              size: 36,
              iconSize: 18,
              active: para.align == DocAlign.right,
              tooltip: 'Right',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: DocAlign.right,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        lineHeight: s.lineHeight,
                        headingLevel: s.headingLevel,
                        list: s.list,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_align_justify_rounded,
              size: 36,
              iconSize: 18,
              active: para.align == DocAlign.justify,
              tooltip: 'Justify',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: DocAlign.justify,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        lineHeight: s.lineHeight,
                        headingLevel: s.headingLevel,
                        list: s.list,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            _divider(c),
            RoundIconButton(
              icon: Icons.format_list_bulleted_rounded,
              size: 36,
              iconSize: 18,
              active: para.list == DocList.bullet,
              tooltip: 'Маркеры',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: s.align,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        headingLevel: s.headingLevel,
                        list: s.list == DocList.bullet ? DocList.none : DocList.bullet,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            RoundIconButton(
              icon: Icons.format_list_numbered_rounded,
              size: 36,
              iconSize: 18,
              active: para.list == DocList.ordered,
              tooltip: 'Нумерация',
              onPressed: enabled
                  ? () => _applyParaStyle((s) => ParaStyle(
                        align: s.align,
                        spaceBefore: s.spaceBefore,
                        spaceAfter: s.spaceAfter,
                        headingLevel: s.headingLevel,
                        list: s.list == DocList.ordered ? DocList.none : DocList.ordered,
                        listLevel: s.listLevel,
                      ))
                  : null,
            ),
            _divider(c),
            _headingPicker(c, enabled),
            _divider(c),
            RoundIconButton(
              icon: Icons.table_chart_outlined,
              size: 36,
              iconSize: 18,
              tooltip: 'Вставить таблицу',
              onPressed: _insertTable,
            ),
            RoundIconButton(
              icon: Icons.horizontal_rule_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Insert rule',
              onPressed: _insertRule,
            ),
            RoundIconButton(
              icon: Icons.horizontal_rule_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Page break',
              onPressed: _insertPageBreak,
            ),
            RoundIconButton(
              icon: Icons.format_color_text_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Цвет текста',
              onPressed: enabled ? _pickColor : null,
            ),
            _divider(c),
            RoundIconButton(
              icon: Icons.format_size_rounded,
              size: 36,
              iconSize: 18,
              tooltip: 'Clear formatting',
              onPressed: enabled
                  ? () {
                      _pushUndo();
                      final b = _doc.blocks[index] as DocTextBlock;
                      b.paragraph.style = const ParaStyle();
                      for (var i = 0; i < b.paragraph.runs.length; i++) {
                        b.paragraph.runs[i] =
                            DocRun(b.paragraph.runs[i].text, const RunStyle());
                      }
                      setState(() => _dirty = true);
                    }
                  : null,
            ),
            RoundIconButton(
              icon: Icons.delete_outline_rounded,
              size: 36,
              iconSize: 18,
              danger: true,
              tooltip: 'Delete block',
              onPressed: enabled && index >= 0 ? () => _deleteBlock(index) : null,
            ),
          ],
        ),
      ),
    );
  }
  RunStyle _flip(
    RunStyle style, {
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
  }) =>
      RunStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        bold: bold == null ? style.bold : !bold,
        italic: italic == null ? style.italic : !italic,
        underline: underline == null ? style.underline : !underline,
        strikethrough: strikethrough == null ? style.strikethrough : !strikethrough,
        color: style.color,
        highlight: style.highlight,
      );
  Widget _fontSize(AppColors c, bool enabled) {
    final block = _focused >= 0 && _focused < _doc.blocks.length
        ? _doc.blocks[_focused]
        : null;
    final current = block is DocTextBlock && block.paragraph.runs.isNotEmpty
        ? (block.paragraph.runs.first.style.fontSize ?? 15).round()
        : 15;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundIconButton(
          icon: Icons.remove_rounded,
          size: 30,
          iconSize: 16,
          tooltip: 'Smaller',
          onPressed: enabled
              ? () => _applyRunStyle(
                    (s) => RunStyle(
                      fontFamily: s.fontFamily,
                      fontSize: ((s.fontSize ?? 15) - 1).clamp(6, 96),
                      bold: s.bold,
                      italic: s.italic,
                      underline: s.underline,
                      strikethrough: s.strikethrough,
                      color: s.color,
                      highlight: s.highlight,
                    ),
                  )
              : null,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: context.t.labelMedium,
          ),
        ),
        RoundIconButton(
          icon: Icons.add_rounded,
          size: 30,
          iconSize: 16,
          tooltip: 'Larger',
          onPressed: enabled
              ? () => _applyRunStyle(
                    (s) => RunStyle(
                      fontFamily: s.fontFamily,
                      fontSize: ((s.fontSize ?? 15) + 1).clamp(6, 96),
                      bold: s.bold,
                      italic: s.italic,
                      underline: s.underline,
                      strikethrough: s.strikethrough,
                      color: s.color,
                      highlight: s.highlight,
                    ),
                  )
              : null,
        ),
      ],
    );
  }
  Widget _headingPicker(AppColors c, bool enabled) {
    final block = _focused >= 0 && _focused < _doc.blocks.length
        ? _doc.blocks[_focused]
        : null;
    final level = block is DocTextBlock ? block.paragraph.style.headingLevel : null;
    return PopupMenuButton<int>(
      tooltip: 'Heading',
      initialValue: level ?? 0,
      onSelected: enabled ? _applyHeading : null,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('Body text')),
        for (var i = 0; i < 6; i++)
          PopupMenuItem(
            value: i,
            child: Text('Heading ${i + 1}'),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: level != null ? c.primarySoft : c.surfaceAlt,
          borderRadius: AppRadius.md,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_size_rounded,
              size: 15,
              color: level != null ? c.primary : c.textDim,
            ),
            const SizedBox(width: 4),
            Text(
              level == null ? 'Body' : 'H${level + 1}',
              style: context.t.labelMedium?.copyWith(
                color: level != null ? c.primary : c.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _pickColor() async {
    final colors = <int>[
      context.c.text.toARGB32(),
      0xFFC08163,
      0xFF7F9079,
      0xFFB08D57,
      0xFF6E8CA0,
      0xFFB5645A,
      0xFF8A8078,
    ];
    final picked = await showRoundedSheet<int>(
      context,
      title: 'Цвет текста',
      child: Wrap(
        spacing: AppSpace.md,
        runSpacing: AppSpace.md,
        children: [
          for (final value in colors)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(value),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(value),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: context.c.border),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    _applyRunStyle(
      (s) => RunStyle(
        fontFamily: s.fontFamily,
        fontSize: s.fontSize,
        bold: s.bold,
        italic: s.italic,
        underline: s.underline,
        strikethrough: s.strikethrough,
        color: picked,
        highlight: s.highlight,
      ),
    );
  }
  Widget _divider(AppColors c) => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        color: c.border,
      );
}
extension on WordDocument {
  double get zoomSafe => 1;
}
class _FindSheet extends StatefulWidget {
  const _FindSheet({required this.onFind, required this.onReplace});
  final void Function(String term) onFind;
  final void Function(String from, String to) onReplace;
  @override
  State<_FindSheet> createState() => _FindSheetState();
}
class _FindSheetState extends State<_FindSheet> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _find,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Find',
            prefixIcon: Icon(Icons.search_rounded, size: 18),
          ),
          onSubmitted: (_) => widget.onFind(_find.text),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _replace,
          decoration: const InputDecoration(
            labelText: 'Replace with',
            prefixIcon: Icon(Icons.swap_horiz_rounded, size: 18),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          children: [
            PillButton(
              label: 'Далее',
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: () => widget.onFind(_find.text),
            ),
            PillButton(
              label: 'Заменить всё',
              primary: true,
              onPressed: () => widget.onReplace(_find.text, _replace.text),
            ),
          ],
        ),
      ],
    );
  }
}
class _PageSetupForm extends StatefulWidget {
  const _PageSetupForm({required this.initial});
  final DocPageSetup initial;
  @override
  State<_PageSetupForm> createState() => _PageSetupFormState();
}
class _PageSetupFormState extends State<_PageSetupForm> {
  late DocPageSetup _value = widget.initial;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A4', label: Text('A4')),
              ButtonSegment(value: 'Letter', label: Text('Letter')),
            ],
            selected: {
              _value.pageWidthPt == 612 ? 'Letter' : 'A4',
            },
            onSelectionChanged: (s) {
              setState(() {
                _value = _value.copyWith(
                  pageWidthPt: s.first == 'Letter' ? 612 : 595,
                  pageHeightPt: s.first == 'Letter' ? 792 : 842,
                );
              });
            },
          ),
          const SizedBox(height: AppSpace.md),
          Text('Orientation', style: context.t.bodyMedium),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Portrait')),
              ButtonSegment(value: true, label: Text('Landscape')),
            ],
            selected: {_value.landscape},
            onSelectionChanged: (s) {
              setState(() {
                _value = _value.copyWith(
                  pageWidthPt: s.first ? 842 : 595,
                  pageHeightPt: s.first ? 595 : 842,
                );
              });
            },
          ),
          const SizedBox(height: AppSpace.md),
          _slider('Margin top', _value.marginTopPt, 0, 200, (v) => _value = _value.copyWith(marginTopPt: v)),
          _slider('Margin bottom', _value.marginBottomPt, 0, 200, (v) => _value = _value.copyWith(marginBottomPt: v)),
          _slider('Margin left', _value.marginLeftPt, 0, 200, (v) => _value = _value.copyWith(marginLeftPt: v)),
          _slider('Margin right', _value.marginRightPt, 0, 200, (v) => _value = _value.copyWith(marginRightPt: v)),
          const SizedBox(height: AppSpace.sm),
          Text('Columns', style: context.t.bodyMedium),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            selected: {_value.columns},
            onSelectionChanged: (s) => setState(() => _value = _value.copyWith(columns: s.first)),
          ),
          const SizedBox(height: AppSpace.lg),
          PillButton(
            label: 'Применить',
            primary: true,
            onPressed: () => Navigator.of(context).pop(_value),
          ),
        ],
      ),
    );
  }
  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChange) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: context.t.bodySmall)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChange(v)),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${value.round()}', style: context.t.labelMedium),
        ),
      ],
    );
  }
}