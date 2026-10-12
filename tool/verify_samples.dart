import 'dart:io';

import 'package:openfiles/features/sheet/sheet_codec.dart';
import 'package:openfiles/features/slides/pptx_codec.dart';
import 'package:openfiles/features/word/docx_codec.dart';

Future<void> main() async {
  final dir = Directory('sample_out');

  final doc = await DocxCodec.load(File('${dir.path}/report.docx').readAsBytesSync());
  stdout.writeln('DOCX  blocks=${doc.blocks.length} words=${doc.wordCount} tables=${doc.tableCount}');
  stdout.writeln('      first="${doc.blocks.whereType<DocTextBlock>().first.paragraph.plainText}"');

  final wb = await XlsxCodec.load(File('${dir.path}/budget.xlsx').readAsBytesSync());
  final s = wb.sheet;
  stdout.writeln('XLSX  sheets=${wb.sheets.length} name=${s.name} rows=${s.maxRow} cols=${s.maxCol}');
  final engine = FormulaEngine(wb);
  stdout.writeln('      A1=${s.cellAt(0, 0).text} F2=${engine.evaluate(s.cellAt(1, 5).formula ?? "")} '
      'B7=${engine.evaluate(s.cellAt(6, 1).formula ?? "")}');

  final deck = await PptxCodec.load(File('${dir.path}/deck.pptx').readAsBytesSync());
  stdout.writeln('PPTX  slides=${deck.slides.length} size=${deck.widthPt}x${deck.heightPt}');
  for (final slide in deck.slides) {
    stdout.writeln('      "${slide.titleText}" elements=${slide.elements.length} '
        'transition=${slide.transition.name} notes="${slide.notes}"');
  }
}