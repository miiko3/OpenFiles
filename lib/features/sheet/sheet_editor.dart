import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/pdf_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/fs_node.dart';
import '../../data/services/saf_service.dart';
import '../../widgets/common.dart';
import 'sheet_codec.dart';
class SheetEditor extends StatefulWidget {
  const SheetEditor({super.key, required this.node});
  final FsNode node;
  @override
  State<SheetEditor> createState() => _SheetEditorState();
}
class _SheetEditorState extends State<SheetEditor> {
  void _goBack() => Navigator.of(context).pop();

  final _saf = SafService.instance;
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _formulaController = TextEditingController();
  final _cellController = TextEditingController();
  final _cellFocus = FocusNode(debugLabel: 'sheetCell');
  late Workbook _wb;
  final List<Workbook> _undo = [];
  final List<Workbook> _redo = [];
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  int _row = 0;
  int _col = 0;
  int? _frozenRow;
  int? _frozenCol;
  int _sheetIndex = 0;
  int? _editRow;
  int? _editCol;
  static const double rowHeight = 32;
  static const double defaultColWidth = 104;
  static const double headerWidth = 46;
  static const int extraRows = 60;
  static const int extraCols = 12;
  Sheet get _sheet => _wb.sheet;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    _formulaController.dispose();
    _cellController.dispose();
    _cellFocus.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
      final wb = await XlsxCodec.load(bytes);
      if (wb.sheets.isEmpty) wb.sheets.add(Sheet('Sheet1'));
      _wb = wb;
      _sheetIndex = 0;
      _syncFormula();
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
    _undo.add(_wb.clone());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }
  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_wb.clone());
    setState(() {
      _wb = _undo.removeLast();
      _syncFormula();
    });
  }
  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_wb.clone());
    setState(() {
      _wb = _redo.removeLast();
      _syncFormula();
    });
  }
  int get _totalRows => _sheet.maxRow + extraRows;
  int get _totalCols => _sheet.maxCol + extraCols;
  double _colWidth(int col) => _sheet.colWidths[col] ?? defaultColWidth;
  int _firstCol = 0;
  int _lastCol = 0;
  double _windowWidth = 0;
  double _stretch = 0;
  void _recalcViewport(double width, double height) {
    final total = math.max(1, _totalCols);
    var end = 1;
    var visible = _colWidth(0);
    while (end < total) {
      final next = visible + _colWidth(end);
      if (next > width) break;
      visible = next;
      end++;
    }
    final last = end.clamp(1, total);
    final extra = visible < width ? width - visible : 0.0;
    _firstCol = 0;
    _lastCol = last;
    _stretch = extra;
    _windowWidth = visible + extra;
  }

  double _gridWidth(int col) {
    if (col == _lastCol - 1) return _colWidth(col) + _stretch;
    return _colWidth(col);
  }
  String _display(int row, int col) {
    final cell = _sheet.cellAt(row, col);
    if (cell.type == CellType.formula) {
      final result = FormulaEngine(_wb).evaluate(
        cell.formula ?? '',
        sheetIndex: _sheetIndex,
      );
      if (result is double) {
        return FormulaEngine.displayOf(
          Cell(type: CellType.number, number: result, style: cell.style),
        );
      }
      if (result is String) return result;
      if (result is bool) return result ? 'TRUE' : 'FALSE';
      return '';
    }
    return FormulaEngine.displayOf(cell);
  }
  void _setActive(int row, int col, {bool edit = true}) {
    _commitEditing();
    setState(() {
      _row = row;
      _col = col;
      _syncFormula();
    });
    if (edit) _beginEdit(row, col);
  }

  bool get _editing => _editRow != null;

  void _beginEdit(int row, int col) {
    final cell = _sheet.cellAt(row, col);
    _editRow = row;
    _editCol = col;
    _cellController.text = cell.type == CellType.formula
        ? '=${cell.formula}'
        : FormulaEngine.displayOf(cell);
    _cellController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _cellController.text.length,
    );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cellFocus.requestFocus();
    });
  }

  void _commitEditing() {
    final row = _editRow;
    final col = _editCol;
    if (row == null || col == null) return;
    _editRow = null;
    _editCol = null;
    _commit(row, col, _cellController.text);
  }

  void _cancelEditing() {
    if (_editRow == null) return;
    _editRow = null;
    _editCol = null;
    setState(() {});
  }

  KeyEventResult _onCellKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift =
        HardwareKeyboard.instance.isShiftPressed ||
        RawKeyboard.instance.keysPressed.any((k) => k == LogicalKeyboardKey.shiftLeft);
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _commitEditing();
      _move(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _commitEditing();
      _move(0, shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _cancelEditing();
      _syncFormula();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  void _syncFormula() {
    final cell = _sheet.cellAt(_row, _col);
    _formulaController.text = cell.type == CellType.formula
        ? '=${cell.formula}'
        : FormulaEngine.displayOf(cell);
  }
  void _commit(int row, int col, String raw) {
    _pushUndo();
    final text = raw.trim();
    Cell cell;
    if (text.isEmpty) {
      cell = Cell.empty;
    } else if (text.startsWith('=')) {
      cell = Cell(type: CellType.formula, formula: text.substring(1));
    } else {
      final number = double.tryParse(text.replaceAll(',', '.'));
      if (number != null) {
        cell = Cell(type: CellType.number, number: number);
      } else {
        final upper = text.toUpperCase();
        if (upper == 'TRUE' || upper == 'FALSE') {
          cell = Cell(type: CellType.bool, boolValue: upper == 'TRUE');
        } else {
          cell = Cell(type: CellType.text, text: text);
        }
      }
    }
    setState(() {
      _sheet.cells.putIfAbsent(row, () => <int, Cell>{})[col] = cell;
      _dirty = true;
    });
  }
  void _move(int rowDelta, int colDelta) {
    setState(() {
      _row = (_row + rowDelta).clamp(0, _totalRows - 1);
      _col = (_col + colDelta).clamp(0, _totalCols - 1);
      _syncFormula();
    });
    if (_editing) _beginEdit(_row, _col);
  }
  void _styleCell(int row, int col, CellStyle style) {
    final cell = _sheet.cellAt(row, col);
    if (style.sameAs(cell.style)) return;
    _put(row, col, cell.withStyle(style));
  }
  void _put(int row, int col, Cell cell) {
    final map = _sheet.cells.putIfAbsent(row, () => <int, Cell>{});
    if (cell.isBlank && cell.style == CellStyle.plain) {
      map.remove(col);
    } else {
      map[col] = cell;
    }
  }
  void _insertRow(int index) {
    _pushUndo();
    setState(() {
      final moved = <int, Map<int, Cell>>{};
      for (final entry in _sheet.cells.entries) {
        final row = entry.key;
        final target = row >= index ? row + 1 : row;
        moved[target] = {...?moved[target], ...entry.value};
      }
      _sheet.cells
        ..clear()
        ..addAll(moved);
      _dirty = true;
    });
  }
  void _deleteRow(int index) {
    _pushUndo();
    setState(() {
      final kept = <int, Map<int, Cell>>{};
      for (final entry in _sheet.cells.entries) {
        if (entry.key == index) continue;
        kept[entry.key > index ? entry.key - 1 : entry.key] = entry.value;
      }
      _sheet.cells
        ..clear()
        ..addAll(kept);
      _dirty = true;
    });
  }
  void _insertCol(int index) {
    _pushUndo();
    setState(() {
      final moved = <int, Map<int, Cell>>{};
      for (final entry in _sheet.cells.entries) {
        final updated = <int, Cell>{};
        for (final cell in entry.value.entries) {
          final target = cell.key >= index ? cell.key + 1 : cell.key;
          updated[target] = cell.value;
        }
        moved[entry.key] = updated;
      }
      _sheet.cells
        ..clear()
        ..addAll(moved);
      _dirty = true;
    });
  }
  void _deleteCol(int index) {
    _pushUndo();
    setState(() {
      for (final row in _sheet.cells.values) {
        if (row.remove(index) == null) {
          final updated = <int, Cell>{};
          for (final entry in row.entries) {
            updated[entry.key > index ? entry.key - 1 : entry.key] = entry.value;
          }
          row
            ..clear()
            ..addAll(updated);
        }
      }
      _dirty = true;
    });
  }
  void _sort({required bool ascending}) {
    final lastCol = _sheet.maxCol;
    if (lastCol < 0) return;
    final rows = <List<Cell>>[];
    for (var r = 0; r < _sheet.maxRow; r++) {
      rows.add([for (var c = 0; c <= lastCol; c++) _sheet.cellAt(r, c)]);
    }
    if (rows.isEmpty) return;
    rows.sort((a, b) {
      final av = FormulaEngine.displayOf(a.first);
      final bv = FormulaEngine.displayOf(b.first);
      final an = double.tryParse(av);
      final bn = double.tryParse(bv);
      final cmp = an != null && bn != null ? an.compareTo(bn) : av.compareTo(bv);
      return ascending ? cmp : -cmp;
    });
    _pushUndo();
    setState(() {
      _sheet.cells.clear();
      for (var r = 0; r < rows.length; r++) {
        final map = <int, Cell>{};
        for (var c = 0; c < rows[r].length; c++) {
          map[c] = rows[r][c];
        }
        _sheet.cells[r] = map;
      }
      _dirty = true;
    });
  }
  Future<void> _save() async {
    _commitEditing();
    try {
      final bytes = await XlsxCodec.save(_wb);
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
  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    for (var r = 0; r < _sheet.maxRow; r++) {
      final row = <String>[];
      for (var c = 0; c < _sheet.maxCol; c++) {
        final value = _display(r, c);
        row.add(value.contains(',') ? '"$value"' : value);
      }
      buffer.writeln(row.join(','));
    }
    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    await Printing.sharePdf(
      bytes: await _csvAsPdf(bytes),
      filename: '${widget.node.name}.csv.pdf',
    );
  }
  Future<Uint8List> _csvAsPdf(Uint8List csvBytes) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(theme: fonts.theme());
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(utf8.decode(csvBytes), style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
    return doc.save();
  }
  Future<void> _exportPdf() async {
    try {
      final fonts = await PdfFonts.load();
      final doc = pw.Document(theme: fonts.theme());
      final rows = _sheet.maxRow;
      final cols = _sheet.maxCol;
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              children: [
                for (var r = 0; r < rows; r++)
                  pw.TableRow(
                    children: [
                      for (var c = 0; c < cols; c++)
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              _display(r, c),
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${widget.node.name}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  Future<void> _insertChart() async {
    final type = await showRoundedSheet<ChartType>(
      context,
      title: 'Вставить диаграмму',
      child: Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          for (final entry in ChartType.values)
            PillButton(
              label: entry.name,
              icon: Icons.bar_chart_rounded,
              onPressed: () => Navigator.of(context).pop(entry),
            ),
        ],
      ),
    );
    if (type == null) return;
    _pushUndo();
    setState(() {
      _sheet.charts.add(
        SheetChart(
          type: type,
          anchorRow: _row,
          anchorCol: _col,
          titleRow: (_row - 1).clamp(0, 100000),
          firstRow: (_row - 1).clamp(0, 100000),
          firstCol: _col,
          lastRow: (_row + 6).clamp(0, 100000),
          lastCol: (_col + 4).clamp(0, 100000),
        ),
      );
      _dirty = true;
    });
  }
  Future<void> _addSheet() async {
    _pushUndo();
    setState(() {
      _wb.sheets.add(Sheet('Sheet${_wb.sheets.length + 1}'));
      _sheetIndex = _wb.sheets.length - 1;
      _dirty = true;
    });
  }
  Future<void> _renameSheet() async {
    final controller = TextEditingController(text: _sheet.name);
    final name = await showRoundedSheet<String>(
      context,
      title: 'Переименовать лист',
      child: TextField(controller: controller, autofocus: true),
    );
    if (name == null || name.trim().isEmpty) return;
    _pushUndo();
    setState(() {
      _sheet.name = name.trim();
      _dirty = true;
    });
  }
  Future<void> _deleteSheet() async {
    if (_wb.sheets.length <= 1) {
      _toast('At least one sheet is required');
      return;
    }
    _pushUndo();
    setState(() {
      _wb.sheets.removeAt(_sheetIndex);
      _sheetIndex = (_sheetIndex - 1).clamp(0, _wb.sheets.length - 1);
      _dirty = true;
    });
  }
  List<double> get _selectionStats {
    var sum = 0.0;
    var count = 0;
    var numeric = 0;
    for (var r = 0; r < _sheet.maxRow; r++) {
      for (var c = 0; c < _sheet.maxCol; c++) {
        final cell = _sheet.cellAt(r, c);
        if (cell.type == CellType.number) {
          sum += cell.number ?? 0;
          numeric++;
          count++;
        } else if (!cell.isBlank) {
          count++;
        }
      }
    }
    return [
      sum,
      count.toDouble(),
      numeric == 0 ? 0 : sum / numeric,
    ];
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) {
      return FileLoadState(
        onBack: _goBack,
        child: const LoadingOverlay(
          visible: true,
          message: 'Opening workbook',
        ),
      );
    }
    if (_error != null) {
      return FileLoadState(
        onBack: _goBack,
        child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
          action: PillButton(
            label: 'Повторить',
            primary: true,
            onPressed: _load,
          ),
        ),
      );
    }
    return Column(
      children: [
        _topBar(c),
        _formulaBar(c),
        Expanded(child: _grid(c)),
        _toolbar(c),
        StatusBar(items: [
          Text('Sum ${_selectionStats[0].toStringAsFixed(2)}'),
          const Spacer(),
          Text('${_selectionStats[1].round()} used'),
          const Spacer(),
          Text('${cellRef(_row, _col)}'),
        ]),
      ],
    );
  }
  Widget _topBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      color: c.bg,
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 34,
                iconSize: 16,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(Icons.table_chart_outlined, size: 18),
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
                icon: Icons.save_outlined,
                size: 34,
                iconSize: 18,
                tooltip: 'Save',
                onPressed: _dirty ? _save : null,
              ),
              RoundIconButton(
                icon: Icons.more_vert_rounded,
                size: 34,
                iconSize: 18,
                tooltip: 'More',
                onPressed: () => _showMenu(c),
              ),
            ],
          ),
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _wb.sheets.length,
              itemBuilder: (context, i) {
                final active = i == _sheetIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _sheetIndex = i;
                      _row = 0;
                      _col = 0;
                      _syncFormula();
                    }),
                    onLongPress: i == _sheetIndex ? _renameSheet : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? c.primarySoft : c.surfaceAlt,
                        borderRadius: AppRadius.md,
                      ),
                      child: Text(
                        _wb.sheets[i].name,
                        style: context.t.labelMedium?.copyWith(
                          color: active ? c.primary : c.textDim,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Новый лист'),
              onTap: () {
                Navigator.of(ctx).pop();
                _addSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Переименовать лист'),
              onTap: () {
                Navigator.of(ctx).pop();
                _renameSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete sheet'),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export PDF'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportCsv();
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  Widget _formulaBar(AppColors c) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            alignment: Alignment.center,
            child: Text(cellRef(_row, _col), style: context.t.labelMedium),
          ),
          const Icon(Icons.functions_rounded, size: 16, color: Color(0xFF8C8075)),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: TextField(
              controller: _formulaController,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: c.text),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (value) {
                _commit(_row, _col, value);
                _syncFormula();
                _move(1, 0);
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _grid(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.xs),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: headerWidth,
            child: Column(
              children: [
                Container(
                  height: rowHeight,
                  width: headerWidth,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    border: Border(
                      right: BorderSide(color: c.border),
                      bottom: BorderSide(color: c.border),
                    ),
                  ),
                  child: _cornerButton(c),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _vScroll,
                    padding: EdgeInsets.zero,
                    itemCount: _totalRows,
                    itemExtent: rowHeight,
                    itemBuilder: (context, r) => _rowHeader(r, c),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _recalcViewport(constraints.maxWidth, constraints.maxHeight);
                return Scrollbar(
                  controller: _hScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _windowWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: rowHeight,
                        child: Row(
                          children: [
                            for (var col = _firstCol; col < _lastCol; col++)
                              SizedBox(
                                width: _gridWidth(col),
                                child: _colHeader(col, c),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: c.border),
                      Expanded(
                        child: ListView.builder(
                          controller: _vScroll,
                          padding: EdgeInsets.zero,
                          itemCount: _totalRows,
                          itemExtent: rowHeight,
                          itemBuilder: (context, r) {
                            return Row(
                              children: [
                                for (var col = _firstCol; col < _lastCol; col++)
                                  SizedBox(
                                    width: _gridWidth(col),
                                    child: _cell(r, col, c),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _cornerButton(AppColors c) {
    return GestureDetector(
      onTap: () => setState(() {
        _frozenRow = null;
        _frozenCol = null;
      }),
      child: Icon(Icons.select_all_rounded, size: 15, color: c.textFaint),
    );
  }
  Widget _rowHeader(int row, AppColors c) {
    final active = row == _row;
    return GestureDetector(
      onTap: () => _setActive(row, _col),
      child: Container(
        width: headerWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.primarySoft : c.surfaceAlt,
          border: Border(
            right: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Text(
          '${row + 1}',
          style: context.t.labelSmall?.copyWith(
            color: active ? c.primary : c.textDim,
          ),
        ),
      ),
    );
  }
  Widget _colHeader(int col, AppColors c) {
    final active = col == _col;
    return GestureDetector(
      onTap: () => _setActive(_row, col),
      onLongPress: () => _columnMenu(col),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.primarySoft : c.surfaceAlt,
          border: Border(
            right: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              columnName(col),
              style: context.t.labelSmall?.copyWith(
                color: active ? c.primary : c.textDim,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _insertCol(col)),
              child: Icon(Icons.add, size: 12, color: c.textFaint),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _columnMenu(int col) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Insert column'),
              onTap: () {
                Navigator.of(ctx).pop();
                _insertCol(col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete column'),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteCol(col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fit_screen_rounded),
              title: const Text('По ширине содержимого'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pushUndo();
                setState(() {
                  var width = 60.0;
                  for (var r = 0; r < _sheet.maxRow; r++) {
                    final length = _display(r, col).length;
                    if (length * 7.5 + 16 > width) width = length * 7.5 + 16;
                  }
                  _sheet.colWidths[col] = width.clamp(60, 420);
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  Widget _cell(int row, int col, AppColors c) {
    if (row > _sheet.maxRow + 1 && col > _sheet.maxCol) {
      return Container(
        width: _gridWidth(col),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: c.border.withValues(alpha: 0.5)),
            bottom: BorderSide(color: c.border.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
    final cell = _sheet.cellAt(row, col);
    final active = row == _row && col == _col;
    final value = _display(row, col);
    return GestureDetector(
      onTap: () => _setActive(row, col),
      onDoubleTap: () => _beginEdit(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: cell.style.fillColor != null
              ? Color(cell.style.fillColor!)
              : (active ? c.primarySoft.withValues(alpha: 0.45) : null),
          border: Border(
            right: BorderSide(color: c.border.withValues(alpha: 0.7)),
            bottom: BorderSide(color: c.border.withValues(alpha: 0.7)),
            left: active ? BorderSide(color: c.primary, width: 1.5) : BorderSide.none,
            top: active ? BorderSide(color: c.primary, width: 1.5) : BorderSide.none,
          ),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: (_editRow == row && _editCol == col)
            ? Focus(
                onKeyEvent: (node, event) => _onCellKey(event),
                child: TextField(
                controller: _cellController,
                focusNode: _cellFocus,
                autofocus: true,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.text,
                style: TextStyle(
                  fontSize: cell.style.fontSize,
                  color: c.text,
                  fontWeight: cell.style.bold ? FontWeight.w700 : FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (v) {
                  _commitEditing();
                  _move(1, 0);
                },
              ),
              )
            : Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: switch (cell.style.align) {
                  'center' => TextAlign.center,
                  'right' => TextAlign.right,
                  _ => TextAlign.left,
                },
                style: TextStyle(
                  fontSize: cell.style.fontSize,
                  height: 1.2,
                  color: cell.style.fontColor != null
                      ? Color(cell.style.fontColor!)
                      : c.text,
                  fontWeight: cell.style.bold ? FontWeight.w700 : FontWeight.w400,
                  fontStyle: cell.style.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: cell.style.underline || cell.style.underline
                      ? TextDecoration.combine([
                          if (cell.style.underline) TextDecoration.underline,
                          if (cell.style.underline) TextDecoration.lineThrough,
                        ])
                      : null,
                  fontFamily: cell.style.fontFamily,
                ),
              ),
      ),
    );
  }
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _pushUndo();
    final lines = text.split('\n');
    setState(() {
      for (var r = 0; r < lines.length; r++) {
        final parts = lines[r].split('\t');
        for (var c = 0; c < parts.length; c++) {
          final raw = parts[c].trim();
          final number = double.tryParse(raw);
          final cell = raw.isEmpty
              ? Cell.empty
              : number != null
                  ? Cell(type: CellType.number, number: number)
                  : Cell(type: CellType.text, text: raw);
          _put(_row + r, _col + c, cell);
        }
      }
      _dirty = true;
    });
  }
  Future<void> _copy() async {
    final cell = _sheet.cellAt(_row, _col);
    final value = cell.type == CellType.formula ? '=${cell.formula}' : _display(_row, _col);
    await Clipboard.setData(ClipboardData(text: value));
  }
  Widget _toolbar(AppColors c) {
    final cell = _sheet.cellAt(_row, _col);
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
              size: 34,
              iconSize: 17,
              tooltip: 'Undo',
              onPressed: _undo.isEmpty ? null : _undoEdit,
            ),
            RoundIconButton(
              icon: Icons.redo_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Redo',
              onPressed: _redo.isEmpty ? null : _redoEdit,
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.format_bold_rounded,
              size: 34,
              iconSize: 17,
              active: cell.style.bold,
              tooltip: 'Bold',
              onPressed: () => _styleCell(_row, _col, CellStyle(
                fontFamily: cell.style.fontFamily,
                fontSize: cell.style.fontSize,
                bold: !cell.style.bold,
                italic: cell.style.italic,
                underline: cell.style.underline,
                fontColor: cell.style.fontColor,
                fillColor: cell.style.fillColor,
                align: cell.style.align,
                valign: cell.style.valign,
                wrap: cell.style.wrap,
                numberFormat: cell.style.numberFormat,
              )),
            ),
            RoundIconButton(
              icon: Icons.format_italic_rounded,
              size: 34,
              iconSize: 17,
              active: cell.style.italic,
              tooltip: 'Italic',
              onPressed: () => _styleCell(_row, _col, CellStyle(
                fontFamily: cell.style.fontFamily,
                fontSize: cell.style.fontSize,
                bold: cell.style.bold,
                italic: !cell.style.italic,
                underline: cell.style.underline,
                fontColor: cell.style.fontColor,
                fillColor: cell.style.fillColor,
                align: cell.style.align,
                valign: cell.style.valign,
                wrap: cell.style.wrap,
                numberFormat: cell.style.numberFormat,
              )),
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.format_align_left_rounded,
              size: 34,
              iconSize: 17,
              active: cell.style.align == 'left',
              tooltip: 'По левому краю',
              onPressed: () => _align('left'),
            ),
            RoundIconButton(
              icon: Icons.format_align_center_rounded,
              size: 34,
              iconSize: 17,
              active: cell.style.align == 'center',
              tooltip: 'Center',
              onPressed: () => _align('center'),
            ),
            RoundIconButton(
              icon: Icons.format_align_right_rounded,
              size: 34,
              iconSize: 17,
              active: cell.style.align == 'right',
              tooltip: 'По правому краю',
              onPressed: () => _align('right'),
            ),
            _sep(c),
            _numberFormatPicker(c, cell),
            _sep(c),
            RoundIconButton(
              icon: Icons.add_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Insert row',
              onPressed: () => _insertRow(_row),
            ),
            RoundIconButton(
              icon: Icons.remove_circle_outline_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Delete row',
              onPressed: () => _deleteRow(_row),
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.sort_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Sort A-Z',
              onPressed: () => _sort(ascending: true),
            ),
            RoundIconButton(
              icon: Icons.sort_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Sort Z-A',
              onPressed: () => _sort(ascending: false),
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.lock_outline_rounded,
              size: 34,
              iconSize: 17,
              active: _frozenRow != null || _frozenCol != null,
              tooltip: 'Freeze',
              onPressed: () => setState(() {
                _frozenRow = _frozenRow == null ? _row + 1 : null;
                _frozenCol = _frozenCol == null ? _col + 1 : null;
              }),
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.content_copy_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Copy',
              onPressed: _copy,
            ),
            RoundIconButton(
              icon: Icons.content_paste_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Paste',
              onPressed: _paste,
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.functions_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Functions',
              onPressed: _insertFunction,
            ),
            RoundIconButton(
              icon: Icons.bar_chart_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Вставить диаграмму',
              onPressed: _insertChart,
            ),
            RoundIconButton(
              icon: Icons.receipt_long_outlined,
              size: 34,
              iconSize: 17,
              tooltip: 'Диаграммы',
              onPressed: _showCharts,
            ),
          ],
        ),
      ),
    );
  }
  void _align(String value) {
    _styleCell(_row, _col, CellStyle(
      fontFamily: _sheet.cellAt(_row, _col).style.fontFamily,
      fontSize: _sheet.cellAt(_row, _col).style.fontSize,
      bold: _sheet.cellAt(_row, _col).style.bold,
      italic: _sheet.cellAt(_row, _col).style.italic,
      underline: _sheet.cellAt(_row, _col).style.underline,
      fontColor: _sheet.cellAt(_row, _col).style.fontColor,
      fillColor: _sheet.cellAt(_row, _col).style.fillColor,
      align: value,
      valign: _sheet.cellAt(_row, _col).style.valign,
      wrap: _sheet.cellAt(_row, _col).style.wrap,
      numberFormat: _sheet.cellAt(_row, _col).style.numberFormat,
    ));
  }
  Widget _numberFormatPicker(AppColors c, Cell cell) {
    const options = [
      'General',
      'Integer',
      'Number',
      'Currency',
      'Percent',
      'Date',
      'Time',
      'Scientific',
    ];
    return PopupMenuButton<String>(
      tooltip: 'Number format',
      initialValue: options.contains(cell.style.numberFormat)
          ? cell.style.numberFormat
          : 'General',
      onSelected: (value) => _styleCell(_row, _col, CellStyle(
        fontFamily: cell.style.fontFamily,
        fontSize: cell.style.fontSize,
        bold: cell.style.bold,
        italic: cell.style.italic,
        underline: cell.style.underline,
        fontColor: cell.style.fontColor,
        fillColor: cell.style.fillColor,
        align: cell.style.align,
        valign: cell.style.valign,
        wrap: cell.style.wrap,
        numberFormat: value,
      )),
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadius.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.percent_rounded, size: 14, color: c.textDim),
            const SizedBox(width: 4),
            Text(cell.style.numberFormat, style: context.t.labelSmall),
          ],
        ),
      ),
    );
  }
  Future<void> _insertFunction() async {
    const functions = [
      'SUM', 'AVERAGE', 'COUNT', 'COUNTA', 'MIN', 'MAX', 'IF', 'SUMIF', 'COUNTIF',
      'ROUND', 'ABS', 'SQRT', 'POWER', 'CONCAT', 'LEFT', 'RIGHT', 'LEN', 'UPPER',
      'LOWER', 'TRIM', 'VLOOKUP', 'INDEX', 'MATCH', 'TODAY', 'NOW', 'STDEV',
    ];
    final picked = await showRoundedSheet<String>(
      context,
      title: 'Вставить функцию',
      child: Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          for (final name in functions)
            PillButton(
              label: name,
              dense: true,
              onPressed: () => Navigator.of(context).pop(name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final ref = cellRef(_row, _col);
    final formula = '$picked($ref)';
    _formulaController.text = '=$formula';
    _commit(_row, _col, '=$formula');
    _syncFormula();
  }
  void _showCharts() {
    if (_sheet.charts.isEmpty) {
      _toast('No charts yet');
      return;
    }
    showRoundedSheet<void>(
      context,
      title: 'Диаграммы',
      child: ListView(
        shrinkWrap: true,
        children: [
          for (var i = 0; i < _sheet.charts.length; i++)
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: Text(_sheet.charts[i].type.name),
              subtitle: Text('Anchor ${cellRef(_sheet.charts[i].anchorRow, _sheet.charts[i].anchorCol)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {
                  setState(() => _sheet.charts.removeAt(i));
                  _dirty = true;
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
  Widget _sep(AppColors c) => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: c.border,
      );
}
extension on CellStyle {
  bool sameAs(CellStyle other) =>
      fontFamily == other.fontFamily &&
      fontSize == other.fontSize &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      fontColor == other.fontColor &&
      fillColor == other.fillColor &&
      align == other.align &&
      valign == other.valign &&
      wrap == other.wrap &&
      numberFormat == other.numberFormat;
}
String formatNumberShort(num value) => NumberFormat('#,##0.##').format(value);
