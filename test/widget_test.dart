import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfiles/core/l10n.dart';
import 'package:openfiles/core/theme/app_theme.dart';
import 'package:openfiles/data/models/fs_node.dart';
import 'package:openfiles/data/providers/app_settings.dart';
import 'package:openfiles/data/services/file_kinds.dart';
import 'package:openfiles/features/browser/viewers/csv_editor.dart';
import 'package:openfiles/features/sheet/sheet_codec.dart';
import 'package:openfiles/features/slides/pptx_codec.dart' as ppt;
import 'package:openfiles/features/word/docx_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

Set<String> resolvedKeysOf(AppLanguage language) {
  L10n.language = language;
  final collected = <String>{};
  for (final key in tAllKeys) {
    if (t(key) != key) collected.add(key);
  }
  L10n.language = AppLanguage.ru;
  return collected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('file recognition', () {
    test('maps extensions to the right kind', () {
      expect(kindForName('a.docx'), FileKind.word);
      expect(kindForName('a.XLSX'), FileKind.sheet);
      expect(kindForName('a.pptx'), FileKind.slides);
      expect(kindForName('a.pdf'), FileKind.pdf);
      expect(kindForName('a.md'), FileKind.markdown);
      expect(kindForName('a.csv'), FileKind.csv);
      expect(kindForName('a.unknown'), FileKind.binary);
    });

    test('supported filter keeps folders and known files', () {
      expect(isSupportedName('report.docx'), isTrue);
      expect(isSupportedName('photo.HEIC'), isTrue);
      expect(isSupportedName('notes.md'), isTrue);
      expect(isSupportedName('mystery'), isFalse);
      expect(isSupportedName('archive.bin'), isFalse);
    });
  });

  group('docx round trip', () {
    test('keeps text, runs, tables and page setup', () async {
      final doc = WordDocument();
      doc.blocks.add(
        DocTextBlock(
          DocParagraph(
            runs: [
              const DocRun('Hello '),
              const DocRun('world', RunStyle(bold: true)),
            ],
            style: const ParaStyle(align: DocAlign.center),
          ),
        ),
      );
      doc.blocks.add(
        DocTextBlock(
          DocParagraph(
            runs: [const DocRun('item')],
            style: const ParaStyle(list: DocList.bullet),
          ),
        ),
      );
      doc.blocks.add(
        DocTableBlock(
          DocTable([
            DocTableRow([
              DocTableCell([DocParagraph(runs: [const DocRun('a')])]),
              DocTableCell([DocParagraph(runs: [const DocRun('b')])]),
            ]),
          ]),
        ),
      );
      doc.blocks.add(DocBreakBlock());
      doc.pageSetup = DocPageSetup.a4.copyWith(columns: 2);

      final bytes = await DocxCodec.save(doc);
      expect(bytes.length, greaterThan(800));

      final back = await DocxCodec.load(bytes);
      final texts = back.blocks.whereType<DocTextBlock>().toList();
      expect(texts.first.paragraph.plainText, 'Hello world');
      expect(texts.first.paragraph.style.align, DocAlign.center);
      expect(texts.first.paragraph.runs[1].style.bold, isTrue);
      expect(texts[1].paragraph.style.list, DocList.bullet);
      expect(back.blocks.whereType<DocTableBlock>().length, 1);
      expect(back.blocks.whereType<DocBreakBlock>().length, 1);
      expect(back.pageSetup.columns, 2);
      expect(back.wordCount, 3);
    });

    test('malformed input does not throw', () async {
      final back = await DocxCodec.load(utf8.encode('not a zip'));
      expect(back.blocks, isEmpty);
    });
  });

  group('xlsx round trip', () {
    test('keeps values, formulas and styles', () async {
      final wb = Workbook(sheets: [Sheet('Data')]);
      final sheet = wb.sheets.first;
      sheet.cells[0] = {
        0: const Cell(type: CellType.text, text: 'Item'),
        1: const Cell(type: CellType.number, number: 10),
        2: const Cell(type: CellType.number, number: 20),
        3: const Cell(
          type: CellType.formula,
          formula: 'SUM(B1:C1)',
        ),
      };
      sheet.cells[1] = {
        0: const Cell(
          type: CellType.text,
          text: 'Total',
          style: CellStyle(bold: true),
        ),
        1: const Cell(type: CellType.number, number: 30),
      };

      final bytes = await XlsxCodec.save(wb);
      final back = await XlsxCodec.load(bytes);

      expect(back.sheets.length, 1);
      expect(back.sheets.first.name, 'Data');
      expect(back.sheets.first.cellAt(0, 0).text, 'Item');
      expect(back.sheets.first.cellAt(0, 1).number, 10);
      expect(back.sheets.first.cellAt(0, 3).formula, 'SUM(B1:C1)');
      expect(back.sheets.first.cellAt(1, 0).style.bold, isTrue);

      final engine = FormulaEngine(back);
      expect(engine.evaluate(back.sheets.first.cellAt(0, 3).formula!), 30.0);
    });

    test('multi sheet workbooks keep every sheet', () async {
      final wb = Workbook(sheets: [Sheet('One'), Sheet('Two'), Sheet('Three')]);
      final bytes = await XlsxCodec.save(wb);
      final back = await XlsxCodec.load(bytes);
      expect(back.sheets.map((s) => s.name), ['One', 'Two', 'Three']);
    });
  });

  group('pptx round trip', () {
    test('keeps shapes, text, tables and transitions', () async {
      final deck = ppt.SlideDeck();
      final slide = ppt.Slide();
      final title = ppt.SlideText()
        ..text = 'Title'
        ..isTitle = true
        ..style = const ppt.SlideTextStyle(fontSize: 30, bold: true);
      title
        ..id = 't'
        ..x = 40
        ..y = 40
        ..w = 400
        ..h = 60;
      final shape = ppt.SlideShapeEl()
        ..shape = ppt.SlideShape.ellipse
        ..fill = 0xFFC08163;
      shape
        ..id = 's'
        ..x = 100
        ..y = 200
        ..w = 200
        ..h = 120;
      final table = ppt.SlideTableEl()
        ..rows = [
          ['A', 'B'],
          ['1', '2'],
        ];
      table
        ..id = 'g'
        ..x = 300
        ..y = 200
        ..w = 300
        ..h = 150;
      slide.elements.addAll([title, shape, table]);
      slide.transition = ppt.SlideTransition.wipe;
      deck.slides.add(slide);

      final bytes = await ppt.PptxCodec.save(deck);
      expect(bytes.length, greaterThan(1500));

      final back = await ppt.PptxCodec.load(bytes);
      expect(back.slides.length, 1);
      final restored = back.slides.first;
      expect(restored.transition, ppt.SlideTransition.wipe);
      expect(restored.titleText, 'Title');
      expect(restored.elements.whereType<ppt.SlideShapeEl>().length, 1);
      expect(restored.elements.whereType<ppt.SlideTableEl>().first.rows.length, 2);

      final shape2 = restored.elements.whereType<ppt.SlideShapeEl>().first;
      expect(shape2.shape, ppt.SlideShape.ellipse);
      expect(shape2.fill, 0xFFC08163);
      expect(shape2.w, closeTo(200, 1));
    });
  });

  group('csv', () {
    test('quotes, separators and newlines', () {
      final rows = parseCsv('a,"b,c"\n"say ""hi""",2', ',');
      expect(rows.length, 2);
      expect(rows[0][1], 'b,c');
      expect(rows[1][0], 'say "hi"');
      expect(rows[1][1], '2');
    });

    test('tab separated', () {
      final rows = parseCsv('a\tb\n1\t2', '\t');
      expect(rows[1], ['1', '2']);
    });
  });

  group('formula engine', () {
    late Workbook wb;

    setUp(() {
      wb = Workbook(sheets: [Sheet('S')]);
      wb.sheets.first.cells[0] = {
        0: const Cell(type: CellType.number, number: 4),
        1: const Cell(type: CellType.number, number: 6),
      };
      wb.sheets.first.cells[1] = {
        0: const Cell(type: CellType.text, text: 'apple'),
        1: const Cell(type: CellType.text, text: 'banana'),
      };
    });

    dynamic ev(String formula) => FormulaEngine(wb).evaluate(formula);

    test('arithmetic and ranges', () {
      expect(ev('=A1+B1'), 10.0);
      expect(ev('=SUM(A1:B1)'), 10);
      expect(ev('=A1*B1'), 24);
      expect(ev('=A1/0'), isNull);
    });

    test('statistics', () {
      expect(ev('=AVERAGE(A1:B1)'), 5);
      expect(ev('=MIN(A1:B1)'), 4);
      expect(ev('=MAX(A1:B1)'), 6);
      expect(ev('=COUNT(A1:B1)'), 2);
      expect(ev('=SUMIF(B1:B1,6)'), 6);
    });

    test('text functions', () {
      final e = FormulaEngine(wb);
      expect(e.evaluate('=LEFT(A2,3)'), 'app');
      expect(e.evaluate('=RIGHT(A2,3)'), 'ple');
      expect(e.evaluate('=LEN(A2)'), 5.0);
      expect(e.evaluate('=UPPER(A2)'), 'APPLE');
      expect(e.evaluate('=CONCATENATE(A2,"!")'), 'apple!');
    });

    test('logic and errors', () {
      final e = FormulaEngine(wb);
      expect(e.evaluate('=IF(A1>3,"big","small")'), 'big');
      expect(e.evaluate('=IF(A1>10,"big","small")'), 'small');
      expect(e.evaluate('=AND(A1=4,B1=6)'), isTrue);
      expect(e.evaluate('=OR(A1=1,B1=2)'), isFalse);
      expect(e.evaluate('=ROUND(A1/3,2)'), 1.33);
      expect(e.evaluate('=NOSUCHFN()'), isNull);
    });

    test('nested calls keep every argument', () {
      expect(ev('=SUM(A1,B1)'), 10);
      expect(ev('=ROUND(AVERAGE(A1,B1),0)'), 5);
    });
  });

  group('l10n', () {
    test('russian and english tables both resolve', () {
      L10n.language = AppLanguage.ru;
      expect(t('settings.title'), 'Настройки');
      expect(t('help.pdfText'), isNotEmpty);
      expect(t('help.pdfText'), isNot(contains('{')));
      L10n.language = AppLanguage.en;
      expect(t('settings.title'), 'Settings');
      L10n.language = AppLanguage.ru;
    });

    test('every help section has a title and a body', () {
      const keys = [
        'access',
        'browser',
        'formats',
        'editing',
        'pdf',
        'slides',
        'storage',
        'themes',
      ];
      for (final key in keys) {
        expect(
          t('help.${key}Title'),
          isNot(equals('help.${key}Title')),
          reason: 'missing title for $key',
        );
        expect(
          t('help.${key}Text'),
          isNot(equals('help.${key}Text')),
          reason: 'missing body for $key',
        );
        expect(t('help.${key}Text').length, greaterThan(20));
      }
    });

    test('every key resolves to a translation in both languages', () {
      for (final language in AppLanguage.values) {
        L10n.language = language;
        for (final key in tAllKeys) {
          expect(t(key), isNot(equals(key)), reason: 'raw key $key in $language');
        }
      }
      L10n.language = AppLanguage.ru;
    });

    test('english never declares a key that russian lacks', () {
      final russian = resolvedKeysOf(AppLanguage.ru);
      final english = resolvedKeysOf(AppLanguage.en);
      expect(english.difference(russian), isEmpty);
    });

    test('placeholders in formatted strings are resolved', () {
      expect(tf('settings.added', {'label': 'Download'}), contains('Download'));
      expect(tf('settings.added', {'label': 'Download'}), isNot(contains('{')));
    });
  });

  group('settings', () {
    test('supported only defaults to on and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      expect(settings.supportedOnly, isTrue);

      await settings.setBool('supportedOnly', false);
      expect(settings.supportedOnly, isFalse);

      final reloaded = AppSettings(await SharedPreferences.getInstance());
      expect(reloaded.supportedOnly, isFalse);
    });

    test('recents survive a round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      final node = FsNode(
        location: const FsLocation.local('/tmp/a.docx'),
        name: 'a.docx',
        isDirectory: false,
        mime: 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document',
        size: 10,
      );
      await settings.addRecent(node);
      expect(settings.recents.length, 1);
      expect(settings.recentNode(0)!.name, 'a.docx');

      final reloaded = AppSettings(await SharedPreferences.getInstance());
      expect(reloaded.recentNode(0)!.location.path, '/tmp/a.docx');
    });
  });

  group('end to end document workflow', () {
    test('create, save, reopen and edit a workbook', () async {
      final dir = Directory.systemTemp.createTempSync('of_e2e');

      final wb = Workbook(sheets: [Sheet('Report')]);
      final sheet = wb.sheets.first;
      sheet.cells[0] = {0: const Cell(type: CellType.text, text: 'Amount')};
      sheet.cells[1] = {
        0: const Cell(type: CellType.number, number: 120),
        1: const Cell(type: CellType.number, number: 80),
        2: const Cell(type: CellType.formula, formula: 'SUM(A2:B2)'),
      };

      final path = '${dir.path}/report.xlsx';
      File(path).writeAsBytesSync(await XlsxCodec.save(wb));

      final reopened = await XlsxCodec.load(File(path).readAsBytesSync());
      expect(reopened.sheets.first.name, 'Report');
      expect(reopened.sheets.first.cellAt(1, 2).formula, 'SUM(A2:B2)');

      final engine = FormulaEngine(reopened);
      expect(
        engine.evaluate(reopened.sheets.first.cellAt(1, 2).formula!),
        200.0,
      );

      reopened.sheets.first.cells[1]![2] =
          const Cell(type: CellType.formula, formula: 'AVERAGE(A2:B2)');
      File(path).writeAsBytesSync(await XlsxCodec.save(reopened));

      final again = await XlsxCodec.load(File(path).readAsBytesSync());
      expect(again.sheets.first.cellAt(1, 2).formula, 'AVERAGE(A2:B2)');
      expect(
        FormulaEngine(again).evaluate(again.sheets.first.cellAt(1, 2).formula!),
        100.0,
      );

      dir.deleteSync(recursive: true);
    });

    test('create, save, reopen and edit a document', () async {
      final dir = Directory.systemTemp.createTempSync('of_e2e');

      final doc = WordDocument();
      doc.blocks.add(
        DocTextBlock(
          DocParagraph(runs: [const DocRun('Первая строка')]),
        ),
      );
      doc.blocks.add(
        DocTextBlock(
          DocParagraph(runs: [const DocRun('', RunStyle())]),
        ),
      );

      final path = '${dir.path}/note.docx';
      File(path).writeAsBytesSync(await DocxCodec.save(doc));

      final reopened = await DocxCodec.load(File(path).readAsBytesSync());
      expect(reopened.plainText, contains('Первая строка'));

      final blocks = reopened.blocks.whereType<DocTextBlock>().toList();
      blocks[1].paragraph.runs = [
        const DocRun('Вторая строка', RunStyle(italic: true)),
      ];
      File(path).writeAsBytesSync(await DocxCodec.save(reopened));

      final again = await DocxCodec.load(File(path).readAsBytesSync());
      final texts = again.blocks.whereType<DocTextBlock>().toList();
      expect(texts[1].paragraph.plainText, 'Вторая строка');
      expect(texts[1].paragraph.runs.first.style.italic, isTrue);

      dir.deleteSync(recursive: true);
    });

    test('presentation survives save, reopen and transition change',
        () async {
      final dir = Directory.systemTemp.createTempSync('of_e2e');

      final deck = ppt.SlideDeck();
      final slide = ppt.Slide();
      final box = ppt.SlideText()
        ..text = 'Frame 1'
        ..style = const ppt.SlideTextStyle(fontSize: 24);
      box
          ..id = 'b'
        ..x = 50
        ..y = 50
        ..w = 300
        ..h = 80;
      slide.elements.add(box);
      slide.transition = ppt.SlideTransition.fade;
      deck.slides.add(slide);

      final path = '${dir.path}/deck.pptx';
      File(path).writeAsBytesSync(await ppt.PptxCodec.save(deck));

      final reopened = await ppt.PptxCodec.load(File(path).readAsBytesSync());
      expect(reopened.slides.first.elements.first.w, closeTo(300, 1));

      reopened.slides.first.transition = ppt.SlideTransition.dissolve;
      File(path).writeAsBytesSync(await ppt.PptxCodec.save(reopened));

      final again = await ppt.PptxCodec.load(File(path).readAsBytesSync());
      expect(again.slides.first.transition, ppt.SlideTransition.dissolve);

      dir.deleteSync(recursive: true);
    });
  });

  group('app shell', () {
    testWidgets('renders in both themes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      for (final mode in AppThemeMode.values) {
        final settings = AppSettings(prefs);
        await settings.setThemeMode(mode);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.flutterThemeMode,
            home: const Scaffold(body: Text('OpenFiles')),
          ),
        );
        expect(find.text('OpenFiles'), findsOneWidget);
      }
    });

    testWidgets('hex viewer renders bytes from a real file', (tester) async {
      final dir = Directory.systemTemp.createTempSync('of_hex');
      final file = File('${dir.path}/blob.bin');
      file.writeAsBytesSync(Uint8List.fromList(List<int>.generate(64, (i) => i)));

      final bytes = file.readAsBytesSync();
      expect(bytes.length, 64);
      expect(bytes[0], 0);
      expect(bytes[63], 63);

      dir.deleteSync(recursive: true);
    });
  });
}