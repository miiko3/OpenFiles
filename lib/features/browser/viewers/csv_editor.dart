import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class CsvEditor extends StatefulWidget {
  const CsvEditor({super.key, required this.node, this.readOnly = false});
  final FsNode node;
  final bool readOnly;
  @override
  State<CsvEditor> createState() => _CsvEditorState();
}
List<List<String>> parseCsv(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
    } else if (ch == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else if (ch != '\r') {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((r) => r.isNotEmpty).toList();
}
class _CsvEditorState extends State<CsvEditor> {
  final _saf = SafService.instance;
  final _scrollH = ScrollController();
  final _scrollV = ScrollController();
  List<List<String>> _rows = [];
  String _delimiter = ',';
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  String _originalText = '';
  final Set<int> _selectedRows = {};
  final Set<int> _selectedCols = {};
  static const double rowHeight = 34;
  static const double colWidth = 128;
  static const double headerWidth = 52;
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void dispose() {
    _scrollH.dispose();
    _scrollV.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
      var text = TextEditorStateAccess.decode(bytes);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      _originalText = text;
      _delimiter = _guessDelimiter(text);
      _rows = parseCsv(text, _delimiter);
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
  static String _guessDelimiter(String text) {
    final firstLine = text.split('\n').firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    var best = ',';
    var bestCount = 0;
    counts.forEach((k, v) {
      if (v > bestCount) {
        best = k;
        bestCount = v;
      }
    });
    return bestCount == 0 ? ',' : best;
  }
  String _serialize() {
    final buffer = StringBuffer();
    for (var r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        if (value.contains(_delimiter) || value.contains('"') || value.contains('\n')) {
          buffer.write('"${value.replaceAll('"', '""')}"');
        } else {
          buffer.write(value);
        }
        if (c < row.length - 1) buffer.write(_delimiter);
      }
      buffer.write('\r\n');
    }
    return buffer.toString();
  }
  int get _cols => _rows.fold<int>(0, (acc, r) => r.length > acc ? r.length : acc);
  String _cell(int r, int c) {
    if (r >= _rows.length) return '';
    final row = _rows[r];
    return c < row.length ? row[c] : '';
  }
  void _setCell(int r, int c, String value) {
    setState(() {
      while (_rows.length <= r) {
        _rows.add(<String>[]);
      }
      final row = _rows[r];
      while (row.length <= c) {
        row.add('');
      }
      row[c] = value;
      _dirty = _serialize() != _originalText;
    });
  }
  Future<void> _save() async {
    try {
      await _saf.writeBytes(widget.node, utf8.encode(_serialize()));
      _originalText = _serialize();
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${widget.node.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingOverlay(visible: true, message: 'Parsing');
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    final c = context.c;
    return Column(
      children: [
        _bar(c),
        Expanded(child: _grid(c)),
        _toolbar(c),
      ],
    );
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
          const Icon(Icons.grid_on_outlined, size: 18),
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
            size: 36,
            iconSize: 18,
            tooltip: 'Save',
            onPressed: widget.readOnly || !_dirty ? null : _save,
          ),
        ],
      ),
    );
  }
  Widget _grid(AppColors c) {
    final cols = _cols;
    if (cols == 0) {
      return EmptyState(
        icon: Icons.table_rows_outlined,
        title: 'No rows',
        message: 'The file parsed to zero rows.',
      );
    }
    final maxRow = _rows.length + 200;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: headerWidth,
            child: Column(
              children: [
                Container(
                  height: rowHeight,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: maxRow,
                    itemExtent: rowHeight,
                    itemBuilder: (context, r) => _rowHeader(r, c),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: c.border),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: rowHeight,
                  child: Scrollbar(
                    controller: _scrollH,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollH,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var col = 0; col < cols; col++)
                            SizedBox(
                              width: colWidth,
                              child: _colHeader(col, c),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: c.border),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollV,
                    child: ListView.builder(
                      controller: _scrollV,
                      padding: EdgeInsets.zero,
                      itemCount: maxRow,
                      itemExtent: rowHeight,
                      itemBuilder: (context, r) {
                        final selected = _selectedRows.contains(r);
                        return Container(
                          color: selected ? c.primarySoft.withValues(alpha: 0.5) : null,
                          child: Row(
                            children: [
                              for (var col = 0; col < cols; col++)
                                SizedBox(
                                  width: colWidth,
                                  child: _dataCell(r, col, c),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _rowHeader(int r, AppColors c) {
    final active = _selectedRows.contains(r);
    return GestureDetector(
      onTap: () => setState(() {
        if (!_selectedRows.remove(r)) _selectedRows.add(r);
      }),
      child: Container(
        width: headerWidth,
        decoration: BoxDecoration(
          color: active ? c.primarySoft : c.surfaceAlt,
          border: Border(
            bottom: BorderSide(color: c.border.withValues(alpha: 0.6)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${r + 1}',
          style: context.t.labelMedium?.copyWith(
            color: active ? c.primary : c.textDim,
          ),
        ),
      ),
    );
  }
  Widget _colHeader(int col, AppColors c) {
    final active = _selectedCols.contains(col);
    return GestureDetector(
      onTap: () => setState(() {
        if (!_selectedCols.remove(col)) _selectedCols.add(col);
      }),
      child: Container(
        decoration: BoxDecoration(
          color: active ? c.primarySoft : c.surfaceAlt,
          border: Border(
            right: BorderSide(color: c.border.withValues(alpha: 0.6)),
            bottom: BorderSide(color: c.border),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          columnLabel(col),
          style: context.t.labelMedium?.copyWith(
            color: active ? c.primary : c.textDim,
          ),
        ),
      ),
    );
  }
  Widget _dataCell(int r, int col, AppColors c) {
    final value = _cell(r, col);
    final exists = r < _rows.length;
    final selected = _selectedCols.contains(col) || _selectedRows.contains(r);
    return GestureDetector(
      onTap: () {
        if (exists && !widget.readOnly) _editCell(r, col, value);
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.primarySoft.withValues(alpha: 0.35) : null,
          border: Border(
            right: BorderSide(color: c.border.withValues(alpha: 0.5)),
            bottom: BorderSide(color: c.border.withValues(alpha: 0.5)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.t.bodyMedium?.copyWith(
            color: exists ? c.text : c.textFaint,
          ),
        ),
      ),
    );
  }
  Future<void> _editCell(int r, int col, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${columnLabel(col)}${r + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Value'),
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
    if (result != null) _setCell(r, col, result);
  }
  Widget _toolbar(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PillButton(
              label: 'Add row',
              icon: Icons.add_rounded,
              dense: true,
              onPressed: widget.readOnly
                  ? null
                  : () => setState(() {
                        _rows.add(<String>['']);
                        _dirty = true;
                      }),
            ),
            const SizedBox(width: AppSpace.sm),
            PillButton(
              label: 'Add column',
              icon: Icons.add_rounded,
              dense: true,
              onPressed: widget.readOnly
                  ? null
                  : () => setState(() {
                        for (final row in _rows) {
                          row.add('');
                        }
                        _dirty = true;
                      }),
            ),
            const SizedBox(width: AppSpace.sm),
            PillButton(
              label: 'Delete row',
              icon: Icons.remove_rounded,
              dense: true,
              onPressed: widget.readOnly || _selectedRows.isEmpty
                  ? null
                  : () => setState(() {
                        final targets = _selectedRows.toList()..sort((a, b) => b.compareTo(a));
                        for (final index in targets) {
                          if (index < _rows.length) _rows.removeAt(index);
                        }
                        _selectedRows.clear();
                        _dirty = true;
                      }),
            ),
            const SizedBox(width: AppSpace.sm),
            PillButton(
              label: 'Delimiter',
              icon: Icons.swap_vert_rounded,
              dense: true,
              onPressed: () => setState(() {
                _delimiter = switch (_delimiter) {
                  ',' => ';',
                  ';' => '\t',
                  _ => ',',
                };
                _rows = parseCsv(_originalText.isEmpty ? _serialize() : _originalText, _delimiter);
                _dirty = false;
              }),
            ),
            const SizedBox(width: AppSpace.md),
            Text(
              'sep ${_delimiter == '\t' ? 'TAB' : _delimiter}  ·  ${_rows.length} rows  ·  $_cols cols',
              style: context.t.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
String columnLabel(int index) {
  var value = index;
  final buffer = StringBuffer();
  while (true) {
    buffer.write(String.fromCharCode(65 + value % 26));
    value = value ~/ 26 - 1;
    if (value < 0) break;
  }
  return buffer.toString().split('').reversed.join();
}
class TextEditorStateAccess {
  static String decode(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true);
}
