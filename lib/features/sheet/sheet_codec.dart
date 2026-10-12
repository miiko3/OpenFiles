import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
String columnName(int index) {
  var value = index;
  final buffer = StringBuffer();
  while (true) {
    buffer.write(String.fromCharCode(65 + value % 26));
    value = value ~/ 26 - 1;
    if (value < 0) break;
  }
  return buffer.toString().split('').reversed.join();
}
int? parseColumn(String name) {
  if (name.isEmpty) return null;
  var value = 0;
  for (final ch in name.toUpperCase().split('')) {
    final code = ch.codeUnitAt(0);
    if (code < 65 || code > 90) return null;
    value = value * 26 + (code - 64);
  }
  return value - 1;
}
String cellRef(int row, int col) => '${columnName(col)}${row + 1}';
enum CellType { empty, number, text, bool, formula, error }
class CellStyle {
  const CellStyle({
    this.fontFamily,
    this.fontSize = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontColor,
    this.fillColor,
    this.align = 'left',
    this.valign = 'center',
    this.wrap = false,
    this.numberFormat = 'General',
    this.boldBorder = false,
  });
  final String? fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final int? fontColor;
  final int? fillColor;
  final String align;
  final String valign;
  final bool wrap;
  final String numberFormat;
  final bool boldBorder;
  CellStyle mergedWith(CellStyle other) => CellStyle(
        fontFamily: other.fontFamily ?? fontFamily,
        fontSize: other.fontSize == 11 ? other.fontSize : other.fontSize,
        bold: other.bold || bold,
        italic: other.italic || italic,
        underline: other.underline || underline,
        fontColor: other.fontColor ?? fontColor,
        fillColor: other.fillColor ?? fillColor,
        align: other.align,
        valign: other.valign,
        wrap: other.wrap || wrap,
        numberFormat: other.numberFormat == 'General'
            ? numberFormat
            : other.numberFormat,
        boldBorder: other.boldBorder || boldBorder,
      );
  static const plain = CellStyle();
}
class Cell {
  const Cell({
    this.type = CellType.empty,
    this.number,
    this.text,
    this.boolValue,
    this.formula,
    this.error,
    this.style = CellStyle.plain,
  });
  final CellType type;
  final double? number;
  final String? text;
  final bool? boolValue;
  final String? formula;
  final String? error;
  final CellStyle style;
  bool get isBlank => type == CellType.empty;
  bool get isNumeric => type == CellType.number;
  static const empty = Cell();
  Cell copyWith({
    CellType? type,
    double? number,
    String? text,
    bool? boolValue,
    String? formula,
    String? error,
    CellStyle? style,
  }) =>
      Cell(
        type: type ?? this.type,
        number: number ?? this.number,
        text: text ?? this.text,
        boolValue: boolValue ?? this.boolValue,
        formula: formula ?? this.formula,
        error: error ?? this.error,
        style: style ?? this.style,
      );
  Cell withStyle(CellStyle value) => Cell(
        type: type,
        number: number,
        text: text,
        boolValue: boolValue,
        formula: formula,
        error: error,
        style: value,
      );
}
class Sheet {
  Sheet(
    this.name, {
    Map<int, Map<int, Cell>>? cells,
    Map<int, double>? rowHeights,
    Map<int, double>? colWidths,
    this.tabColor,
    List<SheetChart>? charts,
  })  : cells = cells ?? <int, Map<int, Cell>>{},
        rowHeights = rowHeights ?? <int, double>{},
        colWidths = colWidths ?? <int, double>{},
        charts = charts ?? <SheetChart>[];
  String name;
  final Map<int, Map<int, Cell>> cells;
  final Map<int, double> rowHeights;
  final Map<int, double> colWidths;
  final int? tabColor;
  final List<SheetChart> charts;
  String name0 = '';
  Cell cellAt(int row, int col) => cells[row]?[col] ?? Cell.empty;
  int get maxRow {
    var max = 0;
    for (final row in cells.keys) {
      final rowIndex = row + 1;
      if (rowIndex > max) max = rowIndex;
    }
    return max;
  }
  int get maxCol {
    var max = 0;
    for (final row in cells.values) {
      for (final col in row.keys) {
        if (col + 1 > max) max = col + 1;
      }
    }
    return max;
  }
  bool get isEmpty => cells.isEmpty;
}
enum ChartType { bar, column, line, area, pie, scatter }
class SheetChart {
  SheetChart({
    required this.type,
    required this.anchorRow,
    required this.anchorCol,
    this.widthRows = 12,
    this.widthCols = 8,
    this.titleRow = 0,
    this.firstRow = 0,
    this.firstCol = 0,
    this.lastRow = 0,
    this.lastCol = 0,
    List<int>? colors,
  }) : colors = colors ?? <int>[];
  final ChartType type;
  final int anchorRow;
  final int anchorCol;
  final int widthRows;
  final int widthCols;
  final int titleRow;
  final int firstRow;
  final int firstCol;
  final int lastRow;
  final int lastCol;
  final List<int> colors;
}
class Workbook {
  Workbook({List<Sheet>? sheets, this.activeSheet = 0, this.title, this.author})
      : sheets = sheets ?? <Sheet>[];
  final List<Sheet> sheets;
  int activeSheet;
  String? title;
  String? author;
  Sheet get sheet => sheets.isEmpty ? Sheet('Sheet1') : sheets[activeSheet.clamp(0, sheets.length - 1)];
  Workbook clone() => Workbook(
        sheets: sheets
            .map((s) => Sheet(
                  s.name,
                  cells: {
                    for (final e in s.cells.entries)
                      e.key: {for (final c in e.value.entries) c.key: c.value},
                  },
                  rowHeights: Map.of(s.rowHeights),
                  colWidths: Map.of(s.colWidths),
                  tabColor: s.tabColor,
                ))
            .toList(),
        activeSheet: activeSheet,
        title: title,
        author: author,
      );
}
class FormulaEngine {
  FormulaEngine(this.workbook);
  final Workbook workbook;
  String? _lastError;
  dynamic evaluate(String formula, {int sheetIndex = 0, int row = 0, int col = 0}) {
    _lastError = null;
    final trimmed = formula.startsWith('=') ? formula.substring(1) : formula;
    final tokens = _tokenize(trimmed);
    final parser = _Parser(tokens);
    final node = parser.parse();
    if (node == null) return _failWith('#ERROR!');
    final value = _eval(node, sheetIndex);
    if (_lastError != null) return _failWith(_lastError!);
    return value;
  }
  double? _failWith(String error) {
    _lastError = error;
    return null;
  }
  static bool isFormula(String text) => text.startsWith('=');
  static String displayOf(Cell cell) {
    switch (cell.type) {
      case CellType.empty:
        return '';
      case CellType.number:
        return _formatNumber(cell.number ?? 0, cell.style.numberFormat);
      case CellType.text:
        return cell.text ?? '';
      case CellType.bool:
        return (cell.boolValue ?? false) ? 'TRUE' : 'FALSE';
      case CellType.error:
        return cell.error ?? '#ERROR!';
      case CellType.formula:
        return '';
    }
  }
  static String _formatNumber(double value, String format) {
    switch (format) {
      case 'Percent':
        return '${(value * 100).toStringAsFixed(1)}%';
      case 'Currency':
        return '\$${value.toStringAsFixed(2)}';
      case 'Integer':
        return value.round().toString();
      case 'Scientific':
        return value.toStringAsExponential(2);
      case 'Date':
        final base = DateTime(1899, 12, 30);
        final date = base.add(Duration(days: value.round()));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'Time':
        final total = value * 24;
        final h = total.floor().toString().padLeft(2, '0');
        final m = ((total - total.floor()) * 60).floor().toString().padLeft(2, '0');
        return '$h:$m';
      case 'Number':
        return value.toStringAsFixed(2);
      default:
        if (value == value.roundToDouble() && value.abs() < 1e15) {
          return value.toStringAsFixed(0);
        }
        return value.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
  }
  List<String> _tokenize(String input) {
    final tokens = <String>[];
    var i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (ch == ' ' || ch == '\t' || ch == '\n') {
        i++;
        continue;
      }
      if (ch == '"') {
        final buffer = StringBuffer();
        i++;
        while (i < input.length) {
          if (input[i] == '"') {
            if (i + 1 < input.length && input[i + 1] == '"') {
              buffer.write('"');
              i += 2;
              continue;
            }
            i++;
            break;
          }
          buffer.write(input[i]);
          i++;
        }
        tokens.add('STR:${buffer.toString()}');
        continue;
      }
      if (ch == '#') {
        final end = input.indexOf(RegExp(r'[^A-Z0-9/!?]'), i);
        final token = end < 0 ? input.substring(i) : input.substring(i, end);
        tokens.add('ERR:$token');
        i += token.length;
        continue;
      }
      if (RegExp(r'[A-Za-z_]').hasMatch(ch)) {
        var j = i;
        while (j < input.length && RegExp(r'[A-Za-z0-9_.]').hasMatch(input[j])) {
          j++;
        }
        final word = input.substring(i, j);
        if (j < input.length && input[j] == '(') {
          tokens.add('FUNC:$word');
        } else {
          var ref = word;
          if (j < input.length && input[j] == '!') {
            j++;
            var k = j;
            while (k < input.length &&
                RegExp(r'[A-Za-z0-9_.$]').hasMatch(input[k])) {
              k++;
            }
            ref = '${word.substring(0, word.length)}!${input.substring(j, k)}';
            j = k;
          }
          tokens.add('REF:$ref');
        }
        i = j;
        continue;
      }
      if (RegExp(r'[0-9]').hasMatch(ch) || (ch == '.' && i + 1 < input.length && RegExp(r'[0-9]').hasMatch(input[i + 1]))) {
        var j = i;
        while (j < input.length && RegExp(r'[0-9.eE+-]').hasMatch(input[j])) {
          if ((input[j] == '+' || input[j] == '-') &&
              !(j > i && RegExp(r'[eE]').hasMatch(input[j - 1]))) {
            break;
          }
          j++;
        }
        tokens.add('NUM:${input.substring(i, j)}');
        i = j;
        continue;
      }
      final two = i + 1 < input.length ? input.substring(i, i + 2) : '';
      if (const ['<=', '>=', '<>'].contains(two)) {
        tokens.add('OP:$two');
        i += 2;
        continue;
      }
      if (const ['+', '-', '*', '/', '^', '=', '<', '>', '&', '(', ')', ',', ':', '%'].contains(ch)) {
        tokens.add('OP:$ch');
        i++;
        continue;
      }
      if (ch == '\$' || RegExp(r'[A-Za-z]').hasMatch(ch)) {
        var j = i;
        while (j < input.length && RegExp(r'[A-Za-z0-9_$]').hasMatch(input[j])) {
          j++;
        }
        tokens.add('REF:${input.substring(i, j)}');
        i = j;
        continue;
      }
      i++;
    }
    return tokens;
  }
  dynamic _eval(_Node node, int sheetIndex) {
    if (_lastError != null) return null;
    switch (node.kind) {
      case _Kind.number:
        return node.number;
      case _Kind.text:
        return node.text;
      case _Kind.error:
        _setError(node.text);
        return null;
      case _Kind.ref:
        final ref = node.text;
        if (ref.toUpperCase() == 'TRUE') return true;
        if (ref.toUpperCase() == 'FALSE') return false;
        return _cellValue(ref, sheetIndex);
      case _Kind.range:
        return _rangeValues(node.text, sheetIndex);
      case _Kind.unary:
        final value = _eval(node.children.first, sheetIndex);
        if (_lastError != null) return null;
        return node.op == '-' ? -_asNumber(value) : _asNumber(value) / 100;
      case _Kind.binary:
        final left = _eval(node.children[0], sheetIndex);
        if (_lastError != null) return null;
        final right = _eval(node.children[1], sheetIndex);
        if (_lastError != null) return null;
        return _binary(node.op, left, right);
      case _Kind.call:
        final args = [
          for (final child in node.children) _eval(child, sheetIndex),
        ];
        if (_lastError != null) return null;
        return _call(node.text.toUpperCase(), args);
    }
  }
  dynamic _cellValue(String ref, int sheetIndex) {
    final parsed = _parseRef(ref, sheetIndex);
    if (parsed == null) return 0.0;
    final (sheet, row, col) = parsed;
    final cell = sheet.cellAt(row, col);
    switch (cell.type) {
      case CellType.empty:
        return 0.0;
      case CellType.number:
        return cell.number ?? 0;
      case CellType.text:
        return cell.text ?? '';
      case CellType.bool:
        return cell.boolValue ?? false;
      case CellType.error:
        _setError(cell.error ?? '#ERROR!');
        return null;
      case CellType.formula:
        return evaluate(cell.formula ?? '', sheetIndex: sheetIndex);
    }
  }
  List<dynamic> _rangeValues(String ref, int sheetIndex) {
    final bounds = _parseRange(ref, sheetIndex);
    if (bounds == null) return const <dynamic>[];
    final (sheet, r0, c0, r1, c1) = bounds;
    final out = <dynamic>[];
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final cell = sheet.cellAt(r, c);
        if (cell.type == CellType.number) {
          out.add(cell.number ?? 0);
        } else if (cell.type == CellType.text) {
          out.add(cell.text ?? '');
        } else if (cell.type == CellType.bool) {
          out.add(cell.boolValue ?? false);
        }
      }
    }
    return out;
  }
  (Sheet, int, int)? _parseRef(String ref, int sheetIndex) {
    final bang = ref.indexOf('!');
    var sheetPart = '';
    var cellPart = ref;
    if (bang > 0) {
      sheetPart = ref.substring(0, bang).replaceAll("'", '');
      cellPart = ref.substring(bang + 1);
    }
    final cellPartClean = cellPart.replaceAll('\$', '');
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cellPartClean);
    if (match == null) return null;
    final col = parseColumn(match.group(1)!);
    final row = int.tryParse(match.group(2)!);
    if (col == null || row == null) return null;
    final sheet = _resolveSheet(sheetPart, sheetIndex);
    return (sheet, row - 1, col);
  }
  (Sheet, int, int, int, int)? _parseRange(String ref, int sheetIndex) {
    final parts = ref.split('!');
    final cellPart = parts.isEmpty ? ref : parts.last;
    final sheetPart = parts.length > 1 ? parts.first.replaceAll("'", '') : '';
    final cells = cellPart.replaceAll('\$', '').split(':');
    if (cells.length != 2) return null;
    final a = _parseRef(cells[0], sheetIndex);
    final b = _parseRef(cells[1], sheetIndex);
    if (a == null || b == null) return null;
    final sheet = _resolveSheet(sheetPart, sheetIndex);
    return (
      sheet,
      a.$2 < b.$2 ? a.$2 : b.$2,
      a.$3 < b.$3 ? a.$3 : b.$3,
      a.$2 > b.$2 ? a.$2 : b.$2,
      a.$3 > b.$3 ? a.$3 : b.$3,
    );
  }
  Sheet _resolveSheet(String name, int fallback) {
    if (name.isEmpty) return workbook.sheets[fallback.clamp(0, workbook.sheets.length - 1)];
    final index = workbook.sheets.indexWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    );
    return workbook.sheets[index < 0 ? 0 : index];
  }
  double _asNumber(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is bool) return value ? 1 : 0;
    return double.tryParse(value.toString()) ?? 0;
  }
  String _asText(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();
    }
    return value.toString();
  }
  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is double) return value != 0;
    final text = value?.toString().toUpperCase() ?? '';
    return text == 'TRUE';
  }
  List<double> _flatten(List<dynamic> args) {
    final out = <double>[];
    void walk(dynamic v) {
      if (v is List) {
        for (final item in v) {
          walk(item);
        }
      } else if (v != null) {
        out.add(_asNumber(v));
      }
    }
    for (final arg in args) {
      walk(arg);
    }
    return out;
  }
  List<String> _flattenText(List<dynamic> args) {
    final out = <String>[];
    void walk(dynamic v) {
      if (v is List) {
        for (final item in v) {
          walk(item);
        }
      } else if (v != null) {
        out.add(_asText(v));
      }
    }
    for (final arg in args) {
      walk(arg);
    }
    return out;
  }
  dynamic _binary(String op, dynamic left, dynamic right) {
    switch (op) {
      case '+':
        if (left is String || right is String) return _asText(left) + _asText(right);
        return _asNumber(left) + _asNumber(right);
      case '-':
        return _asNumber(left) - _asNumber(right);
      case '*':
        return _asNumber(left) * _asNumber(right);
      case '/':
        final divisor = _asNumber(right);
        if (divisor == 0) {
          _setError('#DIV/0!');
();
          return null;
        }
        return _asNumber(left) / divisor;
      case '^':
        return _pow(_asNumber(left), _asNumber(right));
      case '&':
        return _asText(left) + _asText(right);
      case '=':
        return _compare(left, right) == 0;
      case '<>':
        return _compare(left, right) != 0;
      case '<':
        return _compare(left, right) < 0;
      case '>':
        return _compare(left, right) > 0;
      case '<=':
        return _compare(left, right) <= 0;
      case '>=':
        return _compare(left, right) >= 0;
    }
    return null;
  }
  void _setError(String error) {
    _lastError = error;
  }
  double _pow(double base, double exponent) {
    final result = 1.0;
    if (exponent == exponent.roundToDouble()) {
      var b = base;
      var e = exponent.abs().round();
      var acc = 1.0;
      while (e > 0) {
        if (e.isOdd) acc *= b;
        b *= b;
        e ~/= 2;
      }
      return exponent < 0 ? 1 / acc : acc;
    }
    return _log(base) * exponent;
  }
  double _log(double value) {
    var count = 0;
    var v = value;
    while (v > 2) {
      v /= 2;
      count++;
    }
    var sum = (v - 1) / (v + 1);
    var term = sum;
    for (var i = 3; i < 40; i += 2) {
      term *= ((v - 1) / (v + 1)) * ((v - 1) / (v + 1));
      sum += term / i;
    }
    return count * 0.6931471805599453 + sum * 2;
  }
  int _compare(dynamic a, dynamic b) {
    final an = a is num;
    final bn = b is num;
    if (an && bn) return _asNumber(a).compareTo(_asNumber(b));
    final at = _asText(a).toLowerCase();
    final bt = _asText(b).toLowerCase();
    return at.compareTo(bt);
  }
  dynamic _call(String name, List<dynamic> args) {
    switch (name) {
      case 'SUM':
        return _flatten(args).fold<double>(0, (a, b) => a + b);
      case 'AVERAGE':
        final nums = _flatten(args);
        return nums.isEmpty ? 0 : nums.reduce((a, b) => a + b) / nums.length;
      case 'MIN':
        final nums = _flatten(args);
        return nums.isEmpty ? 0 : nums.reduce((a, b) => a < b ? a : b);
      case 'MAX':
        final nums = _flatten(args);
        return nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
      case 'COUNT':
        return _flatten(args).length.toDouble();
      case 'COUNTA':
        return args.where((a) => _asText(a).isNotEmpty).length.toDouble();
      case 'ABS':
        return _asNumber(args.first).abs();
      case 'INT':
        return _asNumber(args.first).truncateToDouble();
      case 'ROUND':
        final digits = args.length > 1 ? _asNumber(args[1]).toInt() : 0;
        return _round(_asNumber(args.first), digits);
      case 'ROUNDUP':
        final digits = args.length > 1 ? _asNumber(args[1]).toInt() : 0;
        final factor = _pow(10, digits.toDouble());
        return (_asNumber(args.first) * factor).ceil() / factor;
      case 'ROUNDDOWN':
        final digits = args.length > 1 ? _asNumber(args[1]).toInt() : 0;
        final factor = _pow(10, digits.toDouble());
        return (_asNumber(args.first) * factor).floor() / factor;
      case 'CEILING':
        final v = _asNumber(args.first);
        return v.ceilToDouble();
      case 'FLOOR':
        return _asNumber(args.first).floorToDouble();
      case 'MOD':
        final divisor = _asNumber(args[1]);
if (divisor == 0) {
          _setError('#DIV/0!');
          return null;
        }
        return _asNumber(args.first) % divisor;
      case 'POWER':
        return _pow(_asNumber(args.first), _asNumber(args[1]));
      case 'SQRT':
        return _sqrt(_asNumber(args.first));
      case 'EXP':
        return _exp(_asNumber(args.first));
      case 'LN':
        return _log(_asNumber(args.first));
      case 'LOG10':
        return _log(_asNumber(args.first)) / 2.302585092994046;
      case 'LOG':
        final base = args.length > 1 ? _asNumber(args[1]) : 10.0;
        return _log(_asNumber(args.first)) / _log(base);
      case 'SIGN':
        final v = _asNumber(args.first);
        return v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);
      case 'GCD':
        return _flatten(args).map((v) => v.round()).fold<int>(0, (a, b) => _gcd(a, b)).toDouble();
      case 'LCM':
        return _flatten(args).map((v) => v.round()).fold<int>(1, (a, b) => a * b ~/ _gcd(a, b)).toDouble();
      case 'PI':
        return 3.14159265358979;
      case 'RAND':
        return _random;
      case 'RANDBETWEEN':
        final lo = _asNumber(args.first).round();
        final hi = _asNumber(args[1]).round();
        return (lo + (_random * (hi - lo + 1)).floor()).toDouble();
      case 'SUMIF':
        return _sumIf(args);
      case 'COUNTIF':
        return _countIf(args);
      case 'SUMIFS':
        return _sumIfs(args);
      case 'SUMPRODUCT':
        if (args.isEmpty) return 0;
        final lists = args.map((a) => _flatten(a)).toList();
        if (lists.isEmpty) return 0;
        var total = 0.0;
        for (var i = 0; i < lists.first.length; i++) {
          var product = 1.0;
          for (final list in lists) {
            product *= i < list.length ? list[i] : 0;
          }
          total += product;
        }
        return total;
      case 'IF':
        return _asBool(args.first)
            ? (args.length > 1 ? args[1] : true)
            : (args.length > 2 ? args[2] : false);
      case 'IFS':
        for (var i = 0; i + 1 < args.length; i += 2) {
          if (_asBool(args[i])) return args[i + 1];
        }
        _lastError = '#N/A';
        return null;
      case 'SWITCH':
        var i = 0;
        while (i + 1 < args.length) {
          if (_compare(args[i], args[i + 1]) == 0) {
            return i + 2 < args.length ? args[i + 2] : true;
          }
          i += 2;
        }
        _lastError = '#N/A';
        return null;
      case 'AND':
        return args.every(_asBool);
      case 'OR':
        return args.any(_asBool);
      case 'NOT':
        return !_asBool(args.first);
      case 'XOR':
        return args.where(_asBool).length.isOdd;
      case 'TRUE':
        return true;
      case 'FALSE':
        return false;
      case 'IFERROR':
        return args.first is ErrorValue ? args[1] : args.first;
      case 'IFNA':
        return args.first is ErrorValue ? args[1] : args.first;
      case 'LEN':
        return _asText(args.first).length.toDouble();
      case 'LEFT':
        final n = args.length > 1 ? _asNumber(args[1]).round() : 1;
        final text = _asText(args.first);
        return text.substring(0, n.clamp(0, text.length));
      case 'RIGHT':
        final n = args.length > 1 ? _asNumber(args[1]).round() : 1;
        final text = _asText(args.first);
        if (n >= text.length) return text;
        return text.substring(text.length - n);
      case 'MID':
        final text = _asText(args.first);
        final start = _asNumber(args[1]).round() - 1;
        final length = _asNumber(args[2]).round();
        if (start < 0 || start >= text.length) return '';
        return text.substring(start, (start + length).clamp(0, text.length));
      case 'UPPER':
        return _asText(args.first).toUpperCase();
      case 'LOWER':
        return _asText(args.first).toLowerCase();
      case 'PROPER':
        final text = _asText(args.first);
        return text
            .split(RegExp(r'(?<=[a-zA-Z])(?=[^a-zA-Z])|(?<=[^a-zA-Z])(?=[a-zA-Z])'))
            .map((w) => w.isEmpty
                ? w
                : w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join();
      case 'TRIM':
        return _asText(args.first).trim().replaceAll(RegExp(r'\s+'), ' ');
      case 'CONCAT':
      case 'CONCATENATE':
        return args.map(_asText).join();
      case 'REPT':
        final times = _asNumber(args[1]).round().clamp(0, 1000);
        return List.filled(times, _asText(args.first)).join();
      case 'REPLACE':
        final text = _asText(args.first);
        final start = _asNumber(args[2]).round() - 1;
        final length = _asNumber(args[3]).round();
        final replacement = _asText(args[4]);
        if (start < 0 || start > text.length) return text;
        return text.substring(0, start) +
            replacement +
            text.substring((start + length).clamp(0, text.length));
      case 'SUBSTITUTE':
        final text = _asText(args.first);
        final target = _asText(args[2]);
        if (target.isEmpty) return text;
        return text.replaceAll(target, _asText(args[3]));
      case 'FIND':
        final index = _asText(args[1]).indexOf(_asText(args.first));
        if (index < 0) {
          _lastError = '#VALUE!';
          return null;
        }
        return (index + 1).toDouble();
      case 'SEARCH':
        final index = _asText(args[1])
            .toLowerCase()
            .indexOf(_asText(args.first).toLowerCase());
        if (index < 0) {
          _lastError = '#VALUE!';
          return null;
        }
        return (index + 1).toDouble();
      case 'TEXT':
        return _formatNumber(_asNumber(args.first), _asText(args[1]));
      case 'VLOOKUP':
        return _lookup(args, true);
      case 'HLOOKUP':
        return _lookup(args, false);
      case 'MATCH':
        final target = args.first;
        final list = _flatten(args[1]);
        final type = args.length > 2 ? _asNumber(args[2]).round() : 1;
        if (type == 0) {
          for (var i = 0; i < list.length; i++) {
            if (_compare(list[i], target) == 0) return (i + 1).toDouble();
          }
        } else {
          for (var i = 0; i < list.length; i++) {
            if (_compare(list[i], target) <= 0) {
              if (i + 1 >= list.length) return (i + 1).toDouble();
              if (_compare(list[i + 1], target) <= 0) continue;
              return (i + 1).toDouble();
            }
          }
        }
        _lastError = '#N/A';
        return null;
      case 'TODAY':
        final now = DateTime.now();
        return (DateTime(now.year, now.month, now.day)
                .difference(DateTime(1899, 12, 30))
                .inDays)
            .toDouble();
      case 'NOW':
        return DateTime.now()
                .difference(DateTime(1899, 12, 30))
                .inMilliseconds /
            86400000;
      case 'YEAR':
      case 'MONTH':
      case 'DAY':
      case 'HOUR':
      case 'MINUTE':
      case 'SECOND':
        final serial = _asNumber(args.first);
        final date = DateTime(1899, 12, 30)
            .add(Duration(minutes: (serial * 1440).round()));
        return switch (name) {
          'YEAR' => date.year.toDouble(),
          'MONTH' => date.month.toDouble(),
          'DAY' => date.day.toDouble(),
          'HOUR' => date.hour.toDouble(),
          'MINUTE' => date.minute.toDouble(),
          _ => date.second.toDouble(),
        };
      case 'STDEV':
        final nums = _flatten(args);
        if (nums.length < 2) return 0.0;
        final mean = nums.reduce((a, b) => a + b) / nums.length;
        final variance = nums
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            (nums.length - 1);
        return _sqrt(variance);
      case 'LARGE':
      case 'SMALL':
        final nums = _flatten(args)..sort();
        final index = _asNumber(args[1]).round();
        if (index < 1 || index > nums.length) {
          _lastError = '#NUM!';
          return null;
        }
        return name == 'LARGE' ? nums[nums.length - index] : nums[index - 1];
      case 'RANK':
        final nums = _flatten(args);
        final value = _asNumber(args.first);
        final ascending = args.length > 2 && _asBool(args[2]);
        final sorted = [...nums]..sort();
        final index = sorted.indexWhere((v) => (v - value).abs() < 1e-9);
        if (index < 0) {
          _lastError = '#N/A';
          return null;
        }
        return (ascending ? index + 1 : sorted.length - index).toDouble();
      case 'ROW':
      case 'COLUMN':
        return 0.0;
      case 'ISBLANK':
        return _asText(args.first).isEmpty;
      case 'ISNUMBER':
        return args.first is num;
      case 'ISTEXT':
        return args.first is String;
      case 'ISERROR':
        return args.first is ErrorValue;
      case 'NA':
        _lastError = '#N/A';
        return null;
    }
    _lastError = '#NAME?';
    return null;
  }
  double get _random => _randomSeed = (_randomSeed * 1103515245 + 12345) % 2147483648 / 2147483648;
  double _randomSeed = 42;
  double _round(double value, int digits) {
    if (digits == 0) return value.roundToDouble();
    final factor = _pow(10, digits.toDouble());
    final scaled = value * factor;
    final rounded = scaled >= 0 ? scaled.roundToDouble() : -scaled.roundToDouble();
    return rounded / factor;
  }
  double _sqrt(double value) {
    if (value < 0) {
      _lastError = '#NUM!';
      return 0;
    }
    if (value == 0) return 0;
    var guess = value / 2;
    if (guess == 0) guess = 1;
    for (var i = 0; i < 40; i++) {
      guess = 0.5 * (guess + value / guess);
    }
    return guess;
  }
  double _exp(double value) {
    var sum = 1.0;
    var term = 1.0;
    for (var i = 1; i < 20; i++) {
      term *= value / i;
      sum += term;
    }
    return sum;
  }
  int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final t = y;
      y = x % y;
      x = t;
    }
    return x == 0 ? 1 : x;
  }
  dynamic _sumIf(List<dynamic> args) {
    if (args.length < 2) return 0.0;
    final range = _asNumbers(args[0]);
    final criteria = args[1];
    final sumRange = args.length > 2 ? _asNumbers(args[2]) : range;
    var total = 0.0;
    for (var i = 0; i < range.length; i++) {
      if (_matches(range[i], criteria) && i < sumRange.length) {
        total += sumRange[i];
      }
    }
    return total;
  }
  dynamic _sumIfs(List<dynamic> args) {
    if (args.length < 3) return 0.0;
    final sumRange = _asNumbers(args.first);
    var total = 0.0;
    var index = 1;
    while (index + 1 < args.length) {
      final range = _asNumbers(args[index]);
      final criteria = args[index + 1];
      for (var i = 0; i < sumRange.length; i++) {
        if (i < range.length && _matches(range[i], criteria)) {
          total += sumRange[i];
        }
      }
      index += 2;
    }
    return total;
  }
  double _countIf(List<dynamic> args) {
    if (args.length < 2) return 0;
    final range = _asNumbers(args[0]);
    var count = 0;
    for (final value in range) {
      if (_matches(value, args[1])) count++;
    }
    return count.toDouble();
  }
  List<double> _asNumbers(dynamic value) =>
      value is List ? value.map(_asNumber).toList() : <double>[_asNumber(value)];
  bool _matches(double value, dynamic criteria) {
    if (criteria is String) {
      final text = criteria;
      final match = RegExp(r'^(<=|>=|<>|<|>|=)(.*)$').firstMatch(text);
      if (match != null) {
        final op = match.group(1)!;
        final operand = double.tryParse(match.group(2)!) ??
            double.tryParse(
                  _asText(value),
                ) ??
            0;
        final v = double.tryParse(_asText(value)) ?? 0;
        switch (op) {
          case '<':
            return v < operand;
          case '>':
            return v > operand;
          case '<=':
            return v <= operand;
          case '>=':
            return v >= operand;
          case '<>':
            return v != operand;
          case '=':
            return (v - operand).abs() < 1e-9;
        }
      }
      if (text.contains('*') || text.contains('?')) {
        final pattern = text.replaceAll('*', '.*').replaceAll('?', '.');
        return RegExp('^$pattern\$', caseSensitive: false).hasMatch(_asText(value));
      }
      return _asText(value).toLowerCase() == text.toLowerCase();
    }
    return (_asNumber(value) - _asNumber(criteria)).abs() < 1e-9;
  }
  dynamic _lookup(List<dynamic> args, bool vertical) {
    if (args.length < 3) {
      _lastError = '#N/A';
      return null;
    }
    final table = args[0] is List
        ? (args[0] as List)
        : [args[0]];
    final target = args[1];
    final columnIndex = _asNumber(args[2]).round() - 1;
    for (var i = 0; i < table.length; i++) {
      final row = table[i];
      final key = row is List ? (row.isNotEmpty ? row.first : null) : row;
      if (_compare(key, target) == 0) {
        if (!vertical) {
          if (i < table.length) {
            return table.length;
          }
          return null;
        }
        final values = row is List ? row : [row];
        if (columnIndex < 0 || columnIndex >= values.length) {
          _lastError = '#REF!';
          return null;
        }
        return values[columnIndex];
      }
    }
    _lastError = '#N/A';
    return null;
  }
}
class _StyleEntry {
  _StyleEntry({
    required this.fontFamily,
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.fontColor,
    required this.fillColor,
    required this.align,
    required this.valign,
    required this.wrap,
    required this.format,
  });

  static int? _colorOrNull(String raw) {
    if (raw.length < 8) return null;
    final value = int.tryParse(raw, radix: 16);
    return value == null || value == 0 ? null : value;
  }

  factory _StyleEntry.parse(String key) {
    final p = key.split('|');
    return _StyleEntry(
      fontFamily: p[0],
      fontSize: double.tryParse(p[1]) ?? 11,
      bold: p[2] == 'true',
      italic: p[3] == 'true',
      underline: p[4] == 'true',
      fontColor: _colorOrNull(p[5]),
      fillColor: _colorOrNull(p[6]),
      align: p[7],
      valign: p[8],
      wrap: p[9] == 'true',
      format: p[10],
    );
  }

  final String fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final int? fontColor;
  final int? fillColor;
  final String align;
  final String valign;
  final bool wrap;
  final String format;

  String get fontKey =>
      '$fontFamily|${fontSize.toStringAsFixed(2)}|$bold|$italic|$underline|'
      '${(fontColor ?? 0).toRadixString(16).padLeft(8, '0')}';

  String get fillHex =>
      (fillColor ?? 0).toRadixString(16).padLeft(8, '0').substring(2);
}
class ErrorValue {
  const ErrorValue(this.code);
  final String code;
}
enum _Kind { number, text, error, ref, range, unary, binary, call }
class _Node {
  _Node(this.kind, {this.number = 0, this.text = '', this.op = '', List<_Node>? children})
      : children = children ?? <_Node>[];
  final _Kind kind;
  final double number;
  final String text;
  final String op;
  final List<_Node> children;
}
class _Parser {
  _Parser(this.tokens);
  final List<String> tokens;
  int _index = 0;
  String? get _current => _index < tokens.length ? tokens[_index] : null;
  _Node? parse() {
    final node = _expression();
    return node;
  }
  _Node? _expression() {
    var left = _comparison();
    return left;
  }
  _Node? _comparison() {
    var left = _concat();
    while (true) {
      final token = _current;
      if (token != null &&
          const ['OP:=', 'OP:<>', 'OP:<', 'OP:>', 'OP:<=', 'OP:>='].contains(token)) {
        _index++;
        final right = _concat();
        if (left == null || right == null) return null;
        left = _Node(_Kind.binary, op: token.substring(3), children: [left, right]);
      } else {
        return left;
      }
    }
  }
  _Node? _concat() {
    var left = _additive();
    while (_current == 'OP:&') {
      _index++;
      final right = _additive();
      if (left == null || right == null) return null;
      left = _Node(_Kind.binary, op: '&', children: [left, right]);
    }
    return left;
  }
  _Node? _additive() {
    var left = _multiplicative();
    while (true) {
      final token = _current;
      if (token == 'OP:+' || token == 'OP:-') {
        _index++;
        final right = _multiplicative();
        if (left == null || right == null) return null;
        left = _Node(
          _Kind.binary,
          op: token!.substring(3),
          children: [left, right],
        );
      } else {
        return left;
      }
    }
  }
  _Node? _multiplicative() {
    var left = _power();
    while (true) {
      final token = _current;
      if (token == 'OP:*' || token == 'OP:/') {
        _index++;
        final right = _power();
        if (left == null || right == null) return null;
        left = _Node(
          _Kind.binary,
          op: token!.substring(3),
          children: [left, right],
        );
      } else {
        return left;
      }
    }
  }
  _Node? _power() {
    final base = _unary();
    if (_current == 'OP:^') {
      _index++;
      final exponent = _power();
      if (base == null || exponent == null) return null;
      return _Node(_Kind.binary, op: '^', children: [base, exponent]);
    }
    return base;
  }
  _Node? _unary() {
    final token = _current;
    if (token == 'OP:-' || token == 'OP:+') {
      _index++;
      final operand = _unary();
      if (operand == null) return null;
      if (token == 'OP:+') return operand;
      return _Node(_Kind.unary, op: '-', children: [operand]);
    }
    return _postfix();
  }
  _Node? _postfix() {
    var node = _primary();
    while (_current == 'OP:%') {
      _index++;
      if (node == null) return null;
      node = _Node(_Kind.unary, op: '%', children: [node]);
    }
    return node;
  }
  _Node? _primary() {
    final token = _current;
    if (token == null) return null;
    if (token == 'OP:(') {
      _index++;
      final inner = _expression();
      if (_current == 'OP:)') _index++;
      return inner;
    }
    if (token.startsWith('NUM:')) {
      _index++;
      return _Node(_Kind.number, number: double.tryParse(token.substring(4)) ?? 0);
    }
    if (token.startsWith('STR:')) {
      _index++;
      return _Node(_Kind.text, text: token.substring(4));
    }
    if (token.startsWith('ERR:')) {
      _index++;
      return _Node(_Kind.error, text: token.substring(4));
    }
    if (token.startsWith('FUNC:')) {
      _index++;
      final children = <_Node>[];
      if (_current == 'OP:(') {
        _index++;
        while (_current != null && _current != 'OP:)') {
          final arg = _expression();
          if (arg != null) children.add(arg);
          if (_current == 'OP:,') {
            _index++;
          } else {
            break;
          }
        }
        if (_current == 'OP:)') _index++;
      }
      return _Node(_Kind.call, text: token.substring(5), children: children);
    }
    if (token.startsWith('REF:')) {
      _index++;
      if (_current == 'OP::' && _index + 1 < tokens.length &&
          tokens[_index + 1].startsWith('REF:')) {
        _index++;
        final second = tokens[_index].substring(4);
        _index++;
        return _Node(_Kind.range, text: '${token.substring(4)}:$second');
      }
      return _Node(_Kind.ref, text: token.substring(4));
    }
    if (token == 'OP:,' || token == 'OP:)' || token == 'OP::') {
      if (token == 'OP::') _index++;
      return _Node(_Kind.number, number: 0);
    }
    _index++;
    return _Node(_Kind.error, text: '#ERROR!');
  }
}
class XlsxCodec {
  const XlsxCodec._();
  static Future<Workbook> load(List<int> bytes) async => _read(bytes);
  static Future<List<int>> save(Workbook wb) async => _write(wb);
  static Workbook _read(List<int> bytes) {
    final workbook = Workbook();
    final archive = ZipDecoder().decodeBytes(bytes);
    final parts = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile && file.content is List<int>) {
        parts[file.name] = Uint8List.fromList(file.content as List<int>);
      }
    }
    final shared = _readSharedStrings(parts['xl/sharedStrings.xml']);
    final styles = _readStyles(parts['xl/styles.xml']);
    final rels = _readRels(parts['xl/_rels/workbook.xml.rels']);
    final workbookXml = parts['xl/workbook.xml'];
    if (workbookXml == null) return workbook;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(workbookXml, allowMalformed: true));
    } catch (_) {
      return workbook;
    }
    for (final sheetEl in doc.findAllElements('sheet')) {
      final name = sheetEl.getAttribute('name') ?? 'Sheet';
      final relId =
          sheetEl.getAttribute('id', namespace: _nsR) ??
              sheetEl.getAttribute('id') ??
              '';
      final target = rels[relId];
      if (target == null) {
        workbook.sheets.add(Sheet(name));
        continue;
      }
      final partName = target.startsWith('xl/') ? target : 'xl/${target.replaceFirst('worksheets/', 'worksheets/')}';
      workbook.sheets.add(_readSheet(parts[partName], name, shared, styles));
    }
    if (workbook.sheets.isEmpty) workbook.sheets.add(Sheet('Sheet1'));
    workbook.title = _firstText(parts['docProps/core.xml'], 'dc:title');
    workbook.author = _firstText(parts['docProps/core.xml'], 'dc:creator');
    return workbook;
  }
  static Sheet _readSheet(
    Uint8List? bytes,
    String name,
    List<String> shared,
    List<CellStyle> styles,
  ) {
    final sheet = Sheet(name);
    if (bytes == null) return sheet;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return sheet;
    }
    for (final col in doc.findAllElements('col')) {
      final min = int.tryParse(col.getAttribute('min') ?? '');
      final max = int.tryParse(col.getAttribute('max') ?? '');
      final width = double.tryParse(col.getAttribute('width') ?? '');
      if (min == null || max == null || width == null) continue;
      for (var i = min; i <= max && i - min < 256; i++) {
        sheet.colWidths[i - 1] = width * 7;
      }
    }
    for (final row in doc.findAllElements('row')) {
      final rowIndex = int.tryParse(row.getAttribute('r') ?? '');
      if (rowIndex == null) continue;
      final height = double.tryParse(row.getAttribute('ht') ?? '');
      if (height != null) sheet.rowHeights[rowIndex - 1] = height * 1.34;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final parsed = _parseRef(ref);
        if (parsed == null) continue;
        final (rowIdx, colIdx) = parsed;
        final type = c.getAttribute('t') ?? 'n';
        final styleIndex =
            int.tryParse(c.getAttribute('s') ?? '') ?? -1;
        final style = styleIndex >= 0 && styleIndex < styles.length
            ? styles[styleIndex]
            : CellStyle.plain;
        final formulaEl = c.findElements('f').firstOrNull;
        final valueEl = c.findElements('v').firstOrNull;
        final inline = c.findElements('is').firstOrNull;
        final formula = formulaEl?.innerText.trim();
        Cell cell = Cell.empty;
        if (type == 's') {
          final index = int.tryParse(valueEl?.innerText ?? '') ?? -1;
          cell = Cell(
            type: CellType.text,
            text: index >= 0 && index < shared.length ? shared[index] : '',
            style: style,
          );
        } else if (type == 'inlineStr') {
          cell = Cell(type: CellType.text, text: inline?.innerText ?? '', style: style);
        } else if (type == 'str') {
          cell = Cell(type: CellType.text, text: valueEl?.innerText ?? '', style: style);
        } else if (type == 'b') {
          cell = Cell(
            type: CellType.bool,
            boolValue: valueEl?.innerText == '1',
            style: style,
          );
        } else if (type == 'e') {
          cell = Cell(type: CellType.error, error: valueEl?.innerText ?? '#ERROR!', style: style);
        } else {
          final raw = valueEl?.innerText;
          final number = double.tryParse(raw ?? '');
          if (number != null) {
            cell = Cell(type: CellType.number, number: number, style: style);
          }
        }
        if (formula != null && formula.isNotEmpty) {
          cell = Cell(
            type: CellType.formula,
            formula: formula,
            style: style,
            number: cell.number,
            text: cell.text,
          );
        }
        if (cell.isBlank && style == CellStyle.plain) continue;
        sheet.cells.putIfAbsent(rowIdx, () => <int, Cell>{})[colIdx] = cell;
      }
    }
    return sheet;
  }
  static (int, int)? _parseRef(String? ref) {
    if (ref == null) return null;
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(ref);
    if (match == null) return null;
    final col = parseColumn(match.group(1)!);
    final row = int.tryParse(match.group(2)!);
    if (col == null || row == null) return null;
    return (row - 1, col);
  }
  static List<String> _readSharedStrings(Uint8List? bytes) {
    final out = <String>[];
    if (bytes == null) return out;
    try {
      final doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      for (final si in doc.findAllElements('si')) {
        out.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    } catch (_) {}
    return out;
  }
  static List<CellStyle> _readStyles(Uint8List? bytes) {
    final out = <CellStyle>[];
    if (bytes == null) return out;
    try {
      final doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      final fonts = doc.findAllElements('fonts').firstOrNull;
      final fills = doc.findAllElements('fills').firstOrNull;
      final numFmts = <int, String>{};
      for (final fmt in doc.findAllElements('numFmt')) {
        final id = int.tryParse(fmt.getAttribute('numFmtId') ?? '');
        if (id != null) numFmts[id] = fmt.getAttribute('formatCode') ?? 'General';
      }
      final fontStyles = <_FontSpec>[];
      for (final font in fonts?.findElements('font') ?? const <XmlElement>[]) {
        fontStyles.add(
          _FontSpec(
            size: double.tryParse(
                  font.findElements('sz').firstOrNull?.getAttribute('val') ?? '',
                ) ??
                11,
            bold: font.findElements('b').isNotEmpty,
            italic: font.findElements('i').isNotEmpty,
            underline: font.findElements('u').isNotEmpty,
            color: _argb(
              font.findElements('color').firstOrNull?.getAttribute('rgb'),
            ),
            family: font.findElements('name').firstOrNull?.getAttribute('val'),
          ),
        );
      }
      final fillStyles = <int?>[];
      for (final fill in fills?.findElements('fill') ?? const <XmlElement>[]) {
        final rgb = fill
            .findAllElements('patternFill')
            .firstOrNull
            ?.findElements('fgColor')
            .firstOrNull
            ?.getAttribute('rgb')
            ;
        fillStyles.add(_argb(rgb));
      }
      final cellXfs = doc.findAllElements('cellXfs').firstOrNull;
      for (final xf in cellXfs?.findElements('xf') ?? const <XmlElement>[]) {
        final fontId = int.tryParse(xf.getAttribute('fontId') ?? '') ?? 0;
        final fillId = int.tryParse(xf.getAttribute('fillId') ?? '') ?? 0;
        final numFmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0;
        final font = fontId < fontStyles.length ? fontStyles[fontId] : _FontSpec(size: 11);
        out.add(
          CellStyle(
            fontFamily: font.family,
            fontSize: font.size,
            bold: font.bold,
            italic: font.italic,
            underline: font.underline,
            fontColor: font.color,
            fillColor: fillId < fillStyles.length ? fillStyles[fillId] : null,
            numberFormat: numFmts[numFmtId] ?? _builtinFormat(numFmtId),
            align: xf.getAttribute('applyAlignment') == '1'
                ? _alignmentName(xf.findElements('alignment').firstOrNull?.getAttribute('horizontal'))
                : 'left',
          ),
        );
      }
    } catch (_) {}
    return out;
  }
  static String _alignmentName(String? value) => switch (value) {
        'center' || 'centerContinuous' => 'center',
        'right' => 'right',
        _ => 'left',
      };
  static String _builtinFormat(int id) => switch (id) {
        1 => 'Integer',
        2 => 'Number',
        3 => 'Integer',
        4 => 'Number',
        9 => 'Percent',
        10 => 'Percent',
        14 => 'Date',
        22 => 'Time',
        _ => 'General',
      };
  static int? _argb(String? rgb) {
    if (rgb == null || rgb.length < 6) return null;
    final parsed = int.tryParse(rgb.substring(rgb.length - 6), radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
  static String? _firstText(Uint8List? bytes, String tag) {
    if (bytes == null) return null;
    try {
      final doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      final value = doc.findAllElements(tag).firstOrNull?.innerText.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
  static Map<String, String> _readRels(Uint8List? bytes) {
    final out = <String, String>{};
    if (bytes == null) return out;
    try {
      final doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) out[id] = target;
      }
    } catch (_) {}
    return out;
  }
  static List<int> _write(Workbook wb) {
    final archive = Archive();
    final strings = <String>[];
    final stringIndex = <String, int>{};
    int intern(String value) {
      final existing = stringIndex[value];
      if (existing != null) return existing;
      final index = strings.length;
      strings.add(value);
      stringIndex[value] = index;
      return index;
    }
    for (final sheet in wb.sheets) {
      for (final row in sheet.cells.values) {
        for (final cell in row.values) {
          if (cell.type == CellType.text && (cell.text ?? '').isNotEmpty) {
            intern(cell.text!);
          }
        }
      }
    }
    for (final sheet in wb.sheets) {
      for (final chart in sheet.charts) {
        intern('Chart');
      }
    }
    archive.addFile(_bytes('[Content_Types].xml', _contentTypes(wb)));
    archive.addFile(_bytes('_rels/.rels', _rootRels));
    archive.addFile(
      _bytes('docProps/core.xml', _coreXml(wb)),
    );
    archive.addFile(
      _bytes('xl/workbook.xml', _workbookXml(wb)),
    );
    archive.addFile(
      _bytes('xl/_rels/workbook.xml.rels', _workbookRels(wb)),
    );
    final styleIndex = _collectStyles(wb);
    archive.addFile(_bytes('xl/styles.xml', _stylesXml(styleIndex)));
    archive.addFile(_bytes('xl/sharedStrings.xml', _sharedStringsXml(strings)));
    for (var i = 0; i < wb.sheets.length; i++) {
      archive.addFile(
        _bytes(
          'xl/worksheets/sheet${i + 1}.xml',
          _sheetXml(wb.sheets[i], stringIndex, styleIndex),
        ),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    return encoded ?? const <int>[];
  }
  static ArchiveFile _bytes(String name, String content) {
    final data = utf8.encode(content);
    return ArchiveFile(name, data.length, data);
  }
  static String _contentTypes(Workbook wb) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>')
      ..write('<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>')
      ..write('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>');
    for (var i = 0; i < wb.sheets.length; i++) {
      b.write(
        '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    b.write('</Types>');
    return b.toString();
  }
  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';
  static String _workbookRels(Workbook wb) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
      ..write('<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rIdShared" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>');
    for (var i = 0; i < wb.sheets.length; i++) {
      b.write(
        '<Relationship Id="rIdSheet$i" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet${i + 1}.xml"/>',
      );
    }
    b.write('</Relationships>');
    return b.toString();
  }
  static String _coreXml(Workbook wb) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'cp:coreProperties',
      attributes: {
        'xmlns:cp': 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties',
        'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
      },
      nest: () {
        b.element('dc:title', nest: wb.title ?? 'Workbook');
        b.element('dc:creator', nest: wb.author ?? 'OpenFiles');
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _workbookXml(Workbook wb) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'workbook',
      attributes: {
        'xmlns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
        'xmlns:r': _nsR,
      },
      nest: () {
        b.element('sheets', nest: () {
          for (var i = 0; i < wb.sheets.length; i++) {
            b.element('sheet', attributes: {
              'name': wb.sheets[i].name,
              'sheetId': '${i + 1}',
              'r:id': 'rIdSheet$i',
            });
          }
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _sharedStringsXml(List<String> strings) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'sst',
      attributes: {
        'xmlns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
        'count': '${strings.length}',
        'uniqueCount': '${strings.length}',
      },
      nest: () {
        for (final value in strings) {
          b.element('si', nest: () => b.element('t', attributes: {'xml:space': 'preserve'}, nest: value));
        }
      },
    );
    return b.buildDocument().toXmlString();
  }
  static Map<String, int> _collectStyles(Workbook wb) {
    final map = <String, int>{};
    for (final sheet in wb.sheets) {
      for (final row in sheet.cells.values) {
        for (final cell in row.values) {
          map.putIfAbsent(_styleKey(cell.style), () => map.length);
        }
      }
    }
    return map;
  }

  static String _styleKey(CellStyle style) {
    final font = (style.fontColor ?? 0).toRadixString(16).padLeft(8, '0');
    final fill = (style.fillColor ?? 0).toRadixString(16).padLeft(8, '0');
    return '${style.fontFamily}|'
        '${style.fontSize}|'
        '${style.bold}|'
        '${style.italic}|'
        '${style.underline}|'
        '$font|'
        '$fill|'
        '${style.align}|'
        '${style.valign}|'
        '${style.wrap}|'
        '${style.numberFormat}';
  }

  static String _stylesXml(Map<String, int> styleIndex) {
    final entries = <_StyleEntry>[];
    for (final key in styleIndex.keys) {
      entries.add(_StyleEntry.parse(key));
    }
    final fontKeys = <String>[];
    final fillKeys = <String>[];
    for (final entry in entries) {
      if (!fontKeys.contains(entry.fontKey)) fontKeys.add(entry.fontKey);
      if (entry.fillColor != null && !fillKeys.contains(entry.fillHex)) {
        fillKeys.add(entry.fillHex);
      }
    }

    const builtin = {
      'General',
      'Integer',
      'Number',
      'Currency',
      'Percent',
      'Date',
      'Time',
      'Scientific',
    };
    final customFormats = <String>[];
    for (final entry in entries) {
      if (!builtin.contains(entry.format) &&
          !customFormats.contains(entry.format)) {
        customFormats.add(entry.format);
      }
    }

    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'styleSheet',
      attributes: {'xmlns': _nsMain},
      nest: () {
        if (customFormats.isNotEmpty) {
          b.element(
            'numFmts',
            attributes: {'count': '${customFormats.length}'},
            nest: () {
              for (var i = 0; i < customFormats.length; i++) {
                b.element('numFmt', attributes: {
                  'numFmtId': '${164 + i}',
                  'formatCode': customFormats[i],
                });
              }
            },
          );
        }

        b.element(
          'fonts',
          attributes: {'count': '${fontKeys.length}'},
          nest: () {
            for (final key in fontKeys) {
              final p = key.split('|');
              b.element('font', nest: () {
                b.element('name', attributes: {
                  'val': p[0].isEmpty ? 'Calibri' : p[0],
                });
                if (p[2] == 'true') b.element('b');
                if (p[3] == 'true') b.element('i');
                if (p[4] == 'true') b.element('u');
                if (p[5] != '00000000') {
                  b.element('color', attributes: {
                    'rgb': p[5].substring(2).toUpperCase(),
                  });
                }
                b.element('sz', attributes: {'val': p[1]});
              });
            }
          },
        );

        b.element(
          'fills',
          attributes: {'count': '${fillKeys.length + 2}'},
          nest: () {
            b.element('fill', nest: () => b.element(
                  'patternFill',
                  attributes: {'patternType': 'none'},
                ));
            b.element('fill', nest: () => b.element(
                  'patternFill',
                  attributes: {'patternType': 'gray125'},
                ));
            for (final hex in fillKeys) {
              b.element('fill', nest: () {
                b.element('patternFill', attributes: {
                  'patternType': 'solid',
                });
                b.element('fgColor', attributes: {'rgb': hex.toUpperCase()});
              });
            }
          },
        );

        b.element('borders', attributes: {'count': '1'}, nest: () => b.element(
              'border',
              nest: () {
                b.element('left');
                b.element('right');
                b.element('top');
                b.element('bottom');
                b.element('diagonal');
              },
            ));

        b.element('cellStyleXfs', attributes: {'count': '1'}, nest: () => b.element(
              'xf',
              attributes: {
                'numFmtId': '0',
                'fontId': '0',
                'fillId': '0',
                'borderId': '0',
              },
            ));

        b.element(
          'cellXfs',
          attributes: {'count': '${entries.length}'},
          nest: () {
            for (final entry in entries) {
              final numFmt = builtin.contains(entry.format)
                  ? 0
                  : 164 + customFormats.indexOf(entry.format);
              final fontId = fontKeys.indexOf(entry.fontKey);
              final fillId =
                  entry.fillColor == null ? 0 : fillKeys.indexOf(entry.fillHex) + 2;
              b.element(
                'xf',
                attributes: {
                  'numFmtId': '$numFmt',
                  'fontId': '$fontId',
                  'fillId': '$fillId',
                  'borderId': '0',
                  'xfId': '0',
                  'applyFont': '1',
                  'applyFill': '1',
                  'applyNumberFormat': '1',
                  'applyAlignment': '1',
                },
                nest: () => b.element('alignment', attributes: {
                  'horizontal': entry.align,
                  'vertical': entry.valign,
                  'wrapText': entry.wrap ? '1' : '0',
                }),
              );
            }
          },
        );
      },
    );
    return b.buildDocument().toXmlString();
  }

  static String _sheetXml(
    Sheet sheet,
    Map<String, int> stringIndex,
    Map<String, int> styleIndex,
  ) {
    final b = XmlBuilder();
    final maxRow = sheet.maxRow;
    final maxCol = sheet.maxCol;
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'worksheet',
      attributes: {'xmlns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'},
      nest: () {
        b.element('dimension', attributes: {'ref': 'A1:${cellRef(maxRow, maxCol)}'});
        if (sheet.colWidths.isNotEmpty) {
          b.element('cols', nest: () {
            for (final entry in sheet.colWidths.entries) {
              b.element('col', attributes: {
                'min': '${entry.key + 1}',
                'max': '${entry.key + 1}',
                'width': '${(entry.value / 7).toStringAsFixed(2)}',
                'customWidth': '1',
              });
            }
          });
        }
        b.element('sheetData', nest: () {
          for (var r = 0; r < maxRow; r++) {
            final row = sheet.cells[r];
            if (row == null) continue;
            b.element('row', attributes: {
              'r': '${r + 1}',
              if (sheet.rowHeights[r] != null)
                'ht': '${(sheet.rowHeights[r]! / 1.34).toStringAsFixed(2)}',
              if (sheet.rowHeights[r] != null) 'customHeight': '1',
            }, nest: () {
              for (var c = 0; c < maxCol; c++) {
                final cell = row[c];
                if (cell == null) continue;
                _writeCell(b, r, c, cell, stringIndex, styleIndex);
              }
            });
          }
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static void _writeCell(
    XmlBuilder b,
    int row,
    int col,
    Cell cell,
    Map<String, int> stringIndex,
    Map<String, int> styleIndex,
  ) {
    final style = styleIndex[_styleKey(cell.style)];
    final ref = cellRef(row, col);
    String? type;
    String? value;
    if (cell.type == CellType.text) {
      type = 's';
      value = '${stringIndex[cell.text] ?? 0}';
    } else if (cell.type == CellType.bool) {
      type = 'b';
      value = (cell.boolValue ?? false) ? '1' : '0';
    } else if (cell.type == CellType.error) {
      type = 'e';
      value = cell.error ?? '#ERROR!';
    } else if (cell.type == CellType.number) {
      value = _numberText(cell.number ?? 0);
    } else if (cell.type == CellType.formula) {
      value = cell.number == null ? null : _numberText(cell.number!);
      type = cell.text != null ? 'str' : null;
      if (type == 'str') value = cell.text;
    }
    b.element('c', attributes: {
      'r': ref,
      if (style != null) 's': '$style',
      if (type != null) 't': type,
    }, nest: () {
      if (cell.formula != null) {
        b.element('f', nest: cell.formula!.startsWith('=') ? cell.formula!.substring(1) : cell.formula!);
      }
      if (value != null) b.element('v', nest: value);
    });
  }
  static String _numberText(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }
  static const _nsMain =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  static const _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
}
class _FontSpec {
  const _FontSpec({
    required this.size,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.family,
  });
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final int? color;
  final String? family;
}
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}