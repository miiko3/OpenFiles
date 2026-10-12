import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openfiles/data/providers/app_settings.dart';
import 'package:openfiles/features/browser/viewers/csv_editor.dart';
import 'package:openfiles/features/sheet/sheet_codec.dart';

void main() {
  test('column names round trip', () {
    expect(columnName(0), 'A');
    expect(columnName(25), 'Z');
    expect(columnName(26), 'AA');
    expect(parseColumn('AA'), 26);
    expect(cellRef(0, 0), 'A1');
  });

  test('csv parsing handles quotes', () {
    final rows = parseCsv('a,"b,c",d\n1,2,3', ',');
    expect(rows.length, 2);
    expect(rows.first[1], 'b,c');
  });

  test('formula engine evaluates basics', () {
    final wb = Workbook(sheets: [Sheet('Sheet1')]);
    wb.sheets.first.cells[0] = {0: const Cell(type: CellType.number, number: 2)};
    wb.sheets.first.cells[0]![1] = const Cell(type: CellType.number, number: 3);
    final engine = FormulaEngine(wb);
    expect(engine.evaluate('=SUM(A1:B1)'), 5.0);
    expect(engine.evaluate('=A1*B1'), 6.0);
    expect(engine.evaluate('=IF(A1>1,"yes","no")'), 'yes');
    expect(engine.evaluate('=CONCATENATE("a","b")'), 'ab');
  });

  test('workbook clone is deep', () {
    final wb = Workbook(sheets: [Sheet('S')]);
    wb.sheets.first.cells[0] = {0: const Cell(type: CellType.text, text: 'x')};
    final copy = wb.clone();
    wb.sheets.first.cells[0]![0] = const Cell(type: CellType.text, text: 'y');
    expect(copy.sheets.first.cellAt(0, 0).text, 'x');
  });

  test('settings defaults load from empty prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    expect(settings.showHidden, isFalse);
    expect(settings.gridView, isFalse);
  });
}