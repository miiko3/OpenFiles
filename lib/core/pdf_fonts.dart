import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Шрифты для экспорта в PDF.
///
/// Встроенные в пакет `pdf` гарнитуры Helvetica и Times не содержат
/// кириллицы, поэтому русский текст в выгруженном файле не отображался.
/// Приложение поставляет Roboto (Apache 2.0) и подставляет его темой документа.
class PdfFonts {
  PdfFonts._(this.regular, this.bold, this.italic, this.boldItalic);

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  static PdfFonts? _cached;

  static Future<PdfFonts> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final fonts = PdfFonts._(
      await _font('assets/fonts/roboto-regular.ttf'),
      await _font('assets/fonts/roboto-bold.ttf'),
      await _font('assets/fonts/roboto-italic.ttf'),
      await _font('assets/fonts/roboto-bolditalic.ttf'),
    );
    _cached = fonts;
    return fonts;
  }

  pw.ThemeData theme() => pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
      );

  static Future<pw.Font> _font(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }
}