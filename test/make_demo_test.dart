import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openfiles/features/sheet/sheet_codec.dart';
import 'package:openfiles/features/slides/pptx_codec.dart' as ppt;
import 'package:openfiles/features/word/docx_codec.dart';

const outRoot = r'C:\Users\123\AppData\Local\Temp\opencode\demo';

void writeFile(String path, List<int> bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

void main() {
  test('generate demo content', () async {
    final root = Directory(outRoot);
    if (root.existsSync()) root.deleteSync(recursive: true);

    writeFile(
      '$outRoot/Документы/Отчёт за квартал.docx',
      await DocxCodec.save(_report()),
    );
    writeFile(
      '$outRoot/Документы/Бюджет.xlsx',
      await XlsxCodec.save(_budget()),
    );
    writeFile(
      '$outRoot/Документы/Презентация.pptx',
      await ppt.PptxCodec.save(_deck()),
    );

    writeFile('$outRoot/Текст и код/Заметки.md', utf8.encode(_markdown()));
    writeFile('$outRoot/Текст и код/Данные.csv', utf8.encode(_csv()));
    writeFile('$outRoot/Текст и код/config.json', utf8.encode(_json()));
    writeFile('$outRoot/Текст и код/main.dart', utf8.encode(_dart()));
    writeFile('$outRoot/Текст и код/Служебная.txt', utf8.encode(_readme()));

    final zip = Archive();
    for (final name in ['Документы/Отчёт за квартал.docx', 'Текст и код/Заметки.md']) {
      final bytes = File('$outRoot/$name').readAsBytesSync();
      zip.addFile(ArchiveFile(name.split('/').last, bytes.length, bytes));
    }
    writeFile('$outRoot/Архивы/Резервная копия.zip', ZipEncoder().encode(zip));

    writeFile('$outRoot/Изображения/Обложка.png', _gradientPng());
    writeFile(
      '$outRoot/Документы/Инструкция.txt',
      utf8.encode('OpenFiles 1.0.3\n\nДемонстрационный набор файлов.\n'),
    );

    var total = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File) {
        total += entity.lengthSync();
        stdout.writeln(
          '${entity.path.substring(outRoot.length + 1)}  ${entity.lengthSync()}',
        );
      }
    }
    stdout.writeln('total $total');
  });
}

WordDocument _report() => WordDocument(
  blocks: [
    DocTextBlock(
      DocParagraph(
        runs: const [DocRun('Отчёт за квартал', RunStyle(bold: true, fontSize: 20))],
        style: const ParaStyle(align: DocAlign.center, spaceAfter: 14),
      ),
    ),
    DocTextBlock(
      DocParagraph(
        runs: const [
          DocRun('Выручка выросла на '),
          DocRun('18', RunStyle(bold: true)),
          DocRun(' процентов относительно прошлого периода.'),
        ],
      ),
    ),
    DocTextBlock(
      DocParagraph(
        runs: const [DocRun('Основные пункты', RunStyle(bold: true))],
        style: const ParaStyle(spaceBefore: 12),
      ),
    ),
    DocTextBlock(
      DocParagraph(
        runs: const [DocRun('Открытие нового раздела')],
        style: const ParaStyle(list: DocList.bullet),
      ),
    ),
    DocTextBlock(
      DocParagraph(
        runs: const [DocRun('Сокращение издержек на логистике')],
        style: const ParaStyle(list: DocList.bullet),
      ),
    ),
    DocTextBlock(
      DocParagraph(
        runs: const [DocRun('Расширение линейки продукции')],
        style: const ParaStyle(list: DocList.bullet),
      ),
    ),
    DocTableBlock(
      DocTable([
        DocTableRow([
          DocTableCell([DocParagraph(runs: const [DocRun('Показатель')])]),
          DocTableCell([DocParagraph(runs: const [DocRun('Значение')])]),
        ]),
        DocTableRow([
          DocTableCell([DocParagraph(runs: const [DocRun('Выручка')])]),
          DocTableCell([DocParagraph(runs: const [DocRun('12 400 000')])]),
        ]),
        DocTableRow([
          DocTableCell([DocParagraph(runs: const [DocRun('Расходы')])]),
          DocTableCell([DocParagraph(runs: const [DocRun('7 900 000')])]),
        ]),
        DocTableRow([
          DocTableCell([DocParagraph(runs: const [DocRun('Прибыль')])]),
          DocTableCell([DocParagraph(runs: const [DocRun('4 500 000')])]),
        ]),
      ]),
    ),
  ],
);

Workbook _budget() {
  final wb = Workbook();
  final sheet = Sheet('Бюджет');
  sheet.cells[0] = {
    0: const Cell(type: CellType.text, text: 'Статья'),
    1: const Cell(type: CellType.text, text: 'План'),
    2: const Cell(type: CellType.text, text: 'Факт'),
  };
  const rows = [
    ['Аренда', '120000', '118500'],
    ['Зарплаты', '340000', '351200'],
    ['Реклама', '85000', '61200'],
    ['Логистика', '47000', '43900'],
    ['Прочее', '23000', '19800'],
  ];
  for (var i = 0; i < rows.length; i++) {
    final row = i + 1;
    sheet.cells[row] = {
      0: Cell(type: CellType.text, text: rows[i][0]),
      1: Cell(type: CellType.number, number: double.parse(rows[i][1])),
      2: Cell(type: CellType.number, number: double.parse(rows[i][2])),
    };
  }
  sheet.cells[6] = {
    0: const Cell(
      type: CellType.text,
      text: 'Итого',
      style: CellStyle(bold: true),
    ),
    1: Cell(
      type: CellType.formula,
      formula: 'SUM(B2:B6)',
      style: const CellStyle(bold: true),
    ),
    2: Cell(
      type: CellType.formula,
      formula: 'SUM(C2:C6)',
      style: const CellStyle(bold: true),
    ),
  };
  sheet.cells[7] = {
    0: const Cell(type: CellType.text, text: 'Отклонение'),
    1: Cell(type: CellType.formula, formula: 'B7-C7'),
    2: Cell(type: CellType.formula, formula: 'C7-B7'),
  };
  wb.sheets.add(sheet);
  return wb;
}

ppt.SlideDeck _deck() {
  final deck = ppt.SlideDeck();

  final cover = ppt.Slide();
  final coverTitle = ppt.SlideText()
    ..text = 'OpenFiles'
    ..isTitle = true
    ..style = const ppt.SlideTextStyle(fontSize: 44, bold: true);
  coverTitle
    ..id = 'c1'
    ..x = 60
    ..y = 160
    ..w = 800
    ..h = 90;
  final coverSub = ppt.SlideText()
    ..text = 'Файлы, которые живут на вашем телефоне'
    ..style = const ppt.SlideTextStyle(fontSize: 22);
  coverSub
    ..id = 'c2'
    ..x = 60
    ..y = 270
    ..w = 800
    ..h = 60;
  cover.elements.addAll([coverTitle, coverSub]);
  cover.transition = ppt.SlideTransition.wipe;
  deck.slides.add(cover);

  final features = ppt.Slide();
  final featuresTitle = ppt.SlideText()
    ..text = 'Что открывается'
    ..isTitle = true
    ..style = const ppt.SlideTextStyle(fontSize: 34, bold: true);
  featuresTitle
    ..id = 'f1'
    ..x = 50
    ..y = 40
    ..w = 820
    ..h = 70;
  final featuresBody = ppt.SlideText()
    ..text =
        'Документы, таблицы, презентации, PDF, текст, код, архивы, фото, видео и музыка.'
    ..style = const ppt.SlideTextStyle(fontSize: 20);
  featuresBody
    ..id = 'f2'
    ..x = 50
    ..y = 140
    ..w = 820
    ..h = 160;
  final badge = ppt.SlideShapeEl()
    ..shape = ppt.SlideShape.roundedRect
    ..fill = 0xFFC08163;
  badge
    ..id = 'f3'
    ..x = 50
    ..y = 330
    ..w = 300
    ..h = 90;
  features.elements.addAll([featuresTitle, featuresBody, badge]);
  features.transition = ppt.SlideTransition.fade;
  deck.slides.add(features);

  final offline = ppt.Slide();
  final offlineTitle = ppt.SlideText()
    ..text = 'Без интернета'
    ..isTitle = true
    ..style = const ppt.SlideTextStyle(fontSize: 34, bold: true);
  offlineTitle
    ..id = 'o1'
    ..x = 50
    ..y = 40
    ..w = 820
    ..h = 70;
  final offlineBody = ppt.SlideText()
    ..text = 'Всё открывается и сохраняется прямо в памяти телефона.'
    ..style = const ppt.SlideTextStyle(fontSize: 20);
  offlineBody
    ..id = 'o2'
    ..x = 50
    ..y = 140
    ..w = 820
    ..h = 120;
  final offlineTable = ppt.SlideTableEl()
    ..rows = [
      ['Формат', 'Просмотр', 'Правка'],
      ['DOCX', 'да', 'да'],
      ['XLSX', 'да', 'да'],
      ['PPTX', 'да', 'да'],
    ];
  offlineTable
    ..id = 'o3'
    ..x = 50
    ..y = 280
    ..w = 620
    ..h = 200;
  offline.elements.addAll([offlineTitle, offlineBody, offlineTable]);
  deck.slides.add(offline);

  return deck;
}

String _markdown() => '''
# Заметки

Приложение работает без интернета и открывает файлы там, где они уже лежат.

## Что открывается

- Документы: DOCX, ODT, RTF
- Таблицы: XLSX, ODS, CSV
- Презентации: PPTX, ODP
- Текст и код: TXT, MD, JSON, Dart, SQL, YAML

## Форматирование

Поддерживаются **полужирный**, *курсив* и \`код в строке\`.

> Совет: тёмная тема включается в настройках.
''';

String _csv() =>
    'Товар;Категория;Цена;Остаток\n'
    'Кофе;Напитки;450;120\n'
    'Чай;Напитки;320;84\n'
    'Кружка;Посуда;890;35\n'
    'Термос;Посуда;2450;12\n';

String _json() => '''
{
  "name": "openfiles",
  "version": "1.0.3",
  "platform": "android",
  "features": ["viewer", "editor", "saf", "offline"]
}
''';

String _dart() => '''
import 'package:flutter/material.dart';

class DemoCard extends StatelessWidget {
  const DemoCard({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Пример карточки'),
      ),
    );
  }
}
''';

String _readme() => '''
OpenFiles 1.0.3

Демонстрационный набор файлов:
  Документы   - DOCX, XLSX, PPTX, TXT
  Текст и код - Markdown, CSV, JSON, Dart
  Изображения - PNG
  Архивы      - ZIP

Все файлы созданы средствами самого приложения.
''';

Uint8List _gradientPng() {
  const size = 720;
  final canvas = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final u = x / size;
      final v = y / size;
      final wave = 0.12 * (u + v);
      canvas.setPixelRgba(
        x,
        y,
        (226 - 96 * u - wave * 40).round().clamp(0, 255),
        (198 - 72 * v).round().clamp(0, 255),
        (172 - 52 * (u * v) - wave * 60).round().clamp(0, 255),
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}