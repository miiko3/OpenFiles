import 'dart:io';

import 'package:openfiles/features/sheet/sheet_codec.dart';
import 'package:openfiles/features/slides/pptx_codec.dart';
import 'package:openfiles/features/word/docx_codec.dart';

Future<void> main() async {
  final out = Directory('sample_out');
  if (!out.existsSync()) out.createSync(recursive: true);

  File('${out.path}/report.docx').writeAsBytesSync(await buildDocx());
  File('${out.path}/budget.xlsx').writeAsBytesSync(await buildXlsx());
  File('${out.path}/deck.pptx').writeAsBytesSync(await buildPptx());
  File('${out.path}/notes.md').writeAsStringSync(buildMarkdown());
  File('${out.path}/data.csv').writeAsStringSync(buildCsv());
  File('${out.path}/hello.txt').writeAsStringSync('OpenFiles works.\n\nSecond line.\n');

  stdout.writeln('generated in ${out.path}');
}

WordDocument buildDoc() {
  final doc = WordDocument(
    meta: const DocMeta(title: 'Quarterly report', author: 'OpenFiles'),
  );

  final title = DocParagraph(
    runs: [DocRun('Quarterly Report', const RunStyle(fontSize: 26, bold: true))],
    style: const ParaStyle(align: DocAlign.center, spaceAfter: 12),
  );
  doc.blocks.add(DocTextBlock(title));

  final intro = DocParagraph(
    runs: [
      const DocRun('Prepared for '),
      const DocRun('the board', RunStyle(bold: true)),
      const DocRun(' on 2026.'),
    ],
    style: const ParaStyle(align: DocAlign.justify, spaceAfter: 8),
  );
  doc.blocks.add(DocTextBlock(intro));

  doc.blocks.add(
    DocTextBlock(
      DocParagraph(
        runs: [const DocRun('Highlights')],
        style: const ParaStyle(headingLevel: 0, spaceBefore: 10),
      ),
    ),
  );

  for (final item in const [
    'Revenue grew 24 percent year over year.',
    'Operating margin improved to 18 percent.',
    'Two new regional offices opened.',
  ]) {
    doc.blocks.add(
      DocTextBlock(
        DocParagraph(
          runs: [DocRun(item)],
          style: const ParaStyle(list: DocList.bullet, spaceAfter: 2),
        ),
      ),
    );
  }

  final table = DocTable();
  for (final row in const [
    ['Region', 'Revenue', 'Growth'],
    ['Europe', '4.2M', '18%'],
    ['Asia', '6.8M', '31%'],
    ['Americas', '3.1M', '12%'],
  ]) {
    table.rows.add(
      DocTableRow(row.map((c) => DocTableCell([DocParagraph(runs: [DocRun(c)])])).toList()),
    );
  }
  doc.blocks.add(DocTableBlock(table));

  doc.blocks.add(DocTextBlock(
    DocParagraph(
      runs: [const DocRun('End of report')],
      style: const ParaStyle(align: DocAlign.center, spaceBefore: 14),
    ),
  ));

  doc.blocks.add(DocBreakBlock());
  doc.blocks.add(
    DocTextBlock(
      DocParagraph(runs: [const DocRun('Appendix')]),
    ),
  );

  return doc;
}

Future<List<int>> buildDocx() async => DocxCodec.save(buildDoc());

Workbook buildBook() {
  final wb = Workbook(title: 'Budget');
  final sheet = Sheet('Budget');

  void put(int row, int col, Cell cell) {
    sheet.cells.putIfAbsent(row, () => <int, Cell>{})[col] = cell;
  }

  const headers = ['Item', 'Q1', 'Q2', 'Q3', 'Q4', 'Total'];
  for (var c = 0; c < headers.length; c++) {
    put(
      0,
      c,
      Cell(
        type: CellType.text,
        text: headers[c],
        style: const CellStyle(bold: true),
      ),
    );
  }

  const items = [
    ['Salaries', 12000, 12500, 13000, 13500],
    ['Marketing', 3000, 3500, 3200, 4000],
    ['Office', 1800, 1800, 1900, 1900],
    ['Travel', 900, 1200, 1500, 1100],
  ];
  for (var r = 0; r < items.length; r++) {
    put(r + 1, 0, Cell(type: CellType.text, text: items[r][0] as String));
    for (var c = 1; c <= 4; c++) {
      put(r + 1, c, Cell(type: CellType.number, number: (items[r][c] as num).toDouble()));
    }
    put(
      r + 1,
      5,
      Cell(type: CellType.formula, formula: 'SUM(B${r + 2}:E${r + 2})'),
    );
  }

  put(6, 0, const Cell(type: CellType.text, text: 'Average', style: CellStyle(bold: true)));
  put(6, 1, const Cell(type: CellType.formula, formula: 'AVERAGE(B2:B5)'));
  put(6, 2, const Cell(type: CellType.formula, formula: 'AVERAGE(C2:C5)'));
  put(6, 3, const Cell(type: CellType.formula, formula: 'MAX(D2:D5)'));
  put(6, 4, const Cell(type: CellType.formula, formula: 'COUNT(E2:E5)'));
  put(6, 5, const Cell(type: CellType.formula, formula: 'SUM(F2:F5)'));

  wb.sheets.add(sheet);
  return wb;
}

Future<List<int>> buildXlsx() async => XlsxCodec.save(buildBook());

SlideDeck buildDeck() {
  final deck = SlideDeck();

  final s1 = Slide();
  final t = SlideText()
    ..text = 'OpenFiles'
    ..isTitle = true
    ..style = const SlideTextStyle(fontSize: 44, bold: true, color: 0xFF3B332C);
  t
    ..id = 's1t'
    ..x = 80
    ..y = 140
    ..w = 800
    ..h = 90;
  final sub = SlideText()
    ..text = 'View and edit every file type'
    ..style = const SlideTextStyle(fontSize: 20, color: 0xFF8C8075);
  sub
    ..id = 's1s'
    ..x = 80
    ..y = 240
    ..w = 800
    ..h = 50;
  final rect = SlideShapeEl()
    ..shape = SlideShape.roundedRect
    ..fill = 0xFFC08163
    ..style = const SlideTextStyle(fontSize: 18, color: 0xFFFFFFFF);
  rect
    ..id = 's1r'
    ..x = 80
    ..y = 330
    ..w = 240
    ..h = 90;
  final tri = SlideShapeEl()
    ..shape = SlideShape.triangle
    ..fill = 0xFF7F9079;
  tri
    ..id = 's1t2'
    ..x = 350
    ..y = 330
    ..w = 140
    ..h = 90;
  s1.elements.addAll([t, sub, rect, tri]);
  s1.notes = 'Welcome the audience.';
  s1.transition = SlideTransition.fade;
  deck.slides.add(s1);

  final s2 = Slide();
  final h2 = SlideText()
    ..text = 'Features'
    ..style = const SlideTextStyle(fontSize: 34, bold: true);
  h2
    ..id = 's2h'
    ..x = 60
    ..y = 50
    ..w = 840
    ..h = 60;
  final body = SlideText()
    ..text = 'Word  Excel  PDF  Slides  Markdown  CSV  Code\n'
        'Images  Audio  Video  Archives'
    ..style = const SlideTextStyle(fontSize: 20);
  body
    ..id = 's2b'
    ..x = 60
    ..y = 140
    ..w = 840
    ..h = 200;
  final arrow = SlideShapeEl()
    ..shape = SlideShape.rightArrow
    ..fill = 0xFFB08D57;
  arrow
    ..id = 's2a'
    ..x = 60
    ..y = 380
    ..w = 320
    ..h = 90;
  s2.elements.addAll([h2, body, arrow]);
  s2.transition = SlideTransition.push;
  deck.slides.add(s2);

  final s3 = Slide();
  final table = SlideTableEl()
    ..rows = [
      ['Format', 'Open', 'Edit'],
      ['DOCX', 'yes', 'yes'],
      ['XLSX', 'yes', 'yes'],
      ['PPTX', 'yes', 'yes'],
      ['PDF', 'yes', 'annotate'],
    ];
  table
    ..id = 's3t'
    ..x = 120
    ..y = 120
    ..w = 720
    ..h = 280;
  s3.elements.add(table);
  s3.transition = SlideTransition.wipe;
  deck.slides.add(s3);

  return deck;
}

Future<List<int>> buildPptx() async => PptxCodec.save(buildDeck());

String buildMarkdown() => '''
# OpenFiles

A file manager that opens **everything**.

## Supported

- Word documents
- Spreadsheets
- PDF files
- Presentations
- Markdown and plain text

## Code

> OpenFiles keeps everything local.

\`\`\`dart
void main() => runApp(const OpenFilesApp());
\`\`\`
''';

String buildCsv() => '''name,region,revenue,growth
Salaries,Europe,4200000,0.18
Marketing,Asia,6800000,0.31
Office,Americas,3100000,0.12
Travel,Europe,900000,0.05
''';
