import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'docx_codec.dart';

class OdtCodec {
  const OdtCodec._();

  static const _mimetype = 'application/vnd.oasis.opendocument.text';

  static Future<WordDocument> load(List<int> bytes) async => _read(bytes);

  static Future<List<int>> save(WordDocument doc) async => _write(doc);

  static WordDocument _read(List<int> bytes) {
    final document = WordDocument();
    ArchiveFile? content;
    for (final file in ZipDecoder().decodeBytes(bytes).files) {
      if (file.isFile && file.name == 'content.xml') content = file;
    }
    if (content == null) return document;
    final text = utf8.decode(Uint8List.fromList(content.content));
    final xml = XmlDocument.parse(text);
    final styles = _readStyles(xml);

    final body = xml.findAllElements('office:text').firstOrNull;
    if (body == null) return document;
    for (final node in body.childElements) {
      switch (node.name.local) {
        case 'p':
        case 'h':
          final paragraph = _readParagraph(node, styles);
          if (paragraph != null) document.blocks.add(DocTextBlock(paragraph));
        case 'list':
          for (final item in node.findElements('list-item')) {
            for (final child in item.childElements) {
              if (child.name.local == 'p' || child.name.local == 'h') {
                final paragraph = _readParagraph(child, styles);
                if (paragraph != null) {
                  paragraph.style = paragraph.style.mergedWith(
                        const ParaStyle(list: DocList.bullet, indentLeft: 18),
                      );
                  document.blocks.add(DocTextBlock(paragraph));
                }
              }
            }
          }
        case 'table':
          final table = _readTable(node, styles);
          if (table != null) document.blocks.add(DocTableBlock(table));
        case 'section':
          for (final child in node.childElements) {
            if (child.name.local == 'p' || child.name.local == 'h') {
              final paragraph = _readParagraph(child, styles);
              if (paragraph != null) document.blocks.add(DocTextBlock(paragraph));
            }
          }
      }
    }
    return document;
  }

  static DocParagraph? _readParagraph(XmlElement node, _OdtStyles styles) {
    final name = node.getAttribute('text:style-name');
    final para = styles.paragraphs[name] ?? const ParaStyle();
    final level = node.name.local == 'h'
        ? int.tryParse(node.getAttribute('text:outline-level') ?? '1') ?? 1
        : null;
    final runs = <DocRun>[];
    _collectRuns(node, styles, runs, const RunStyle());
    if (runs.isEmpty && (node.innerText.trim().isEmpty)) {
      return DocParagraph(runs: const [], style: para);
    }
    return DocParagraph(
      runs: runs,
      style: para.mergedWith(ParaStyle(headingLevel: level)),
    );
  }

  static void _collectRuns(
    XmlElement node,
    _OdtStyles styles,
    List<DocRun> out,
    RunStyle inherited,
  ) {
    for (final child in node.childElements) {
      final local = child.name.local;
      final styleName = child.getAttribute('text:style-name');
      final style = styles.runs[styleName] ?? const RunStyle();
      final merged = inherited.mergedWith(style);
      if (local == 's') {
        final count = int.tryParse(child.getAttribute('text:c') ?? '1') ?? 1;
        out.add(DocRun(' ' * count, merged));
        continue;
      }
      if (local == 'tab') {
        out.add(DocRun('\t', merged));
        continue;
      }
      if (local == 'line-break') {
        out.add(DocRun('\n', merged));
        continue;
      }
      final inner = child.childElements.isEmpty
          ? child.innerText
          : null;
      if (inner != null) {
        if (inner.isNotEmpty) out.add(DocRun(inner, merged));
      } else {
        _collectRuns(child, styles, out, merged);
      }
    }
  }

  static DocTable? _readTable(XmlElement node, _OdtStyles styles) {
    final table = DocTable();
    for (final rowNode in node.findElements('table:table-row')) {
      final row = DocTableRow();
      for (final cellNode in rowNode.findElements('table:table-cell')) {
        final cell = DocTableCell();
        for (final child in cellNode.childElements) {
          if (child.name.local == 'p' || child.name.local == 'h') {
            final paragraph = _readParagraph(child, styles);
            if (paragraph != null) cell.paragraphs.add(paragraph);
          }
        }
        if (cell.paragraphs.isEmpty) {
          cell.paragraphs.add(DocParagraph(runs: const []));
        }
        row.cells.add(cell);
      }
      if (row.cells.isNotEmpty) table.rows.add(row);
    }
    if (table.rows.isEmpty) return null;
    return table;
  }

  static _OdtStyles _readStyles(XmlDocument xml) {
    final paragraphs = <String, ParaStyle>{};
    final runs = <String, RunStyle>{};
    final declared = <String, String>{};
    for (final style in xml.findAllElements('style:style')) {
      final name = style.getAttribute('style:name');
      if (name != null) declared[name] = style.getAttribute('style:parent-style-name') ?? '';
    }
    for (final style in xml.findAllElements('style:style')) {
      final name = style.getAttribute('style:name');
      if (name == null) continue;
      var run = const RunStyle();
      var para = const ParaStyle();
      var guard = 0;
      var cursor = style;
      while (guard++ < 8) {
        final textProps = cursor.findElements('style:text-properties').firstOrNull;
        if (textProps != null) {
          run = run.mergedWith(RunStyle(
            fontFamily: textProps.getAttribute('fo:font-family'),
            fontSize: _points(textProps.getAttribute('fo:font-size')),
            bold: textProps.getAttribute('fo:font-weight') == 'bold' ||
                textProps.getAttribute('style:font-weight-asian') == 'bold',
            italic: textProps.getAttribute('fo:font-style') == 'italic',
            underline:
                textProps.getAttribute('style:text-underline-style') != null &&
                    textProps.getAttribute('style:text-underline-style') != 'none',
            strikethrough:
                textProps.getAttribute('style:text-line-through-style') == 'solid',
          ));
        }
        final paraProps = cursor.findElements('style:paragraph-properties').firstOrNull;
        if (paraProps != null) {
          para = para.mergedWith(ParaStyle(
            align: _align(paraProps.getAttribute('fo:text-align')),
            spaceBefore: _points(paraProps.getAttribute('fo:margin-top')),
            spaceAfter: _points(paraProps.getAttribute('fo:margin-bottom')),
            indentLeft: _points(paraProps.getAttribute('fo:margin-left')),
            indentRight: _points(paraProps.getAttribute('fo:margin-right')),
            indentFirstLine: _points(paraProps.getAttribute('fo:text-indent')),
          ));
        }
        final parent = cursor.getAttribute('style:parent-style-name');
        if (parent == null) break;
        final next = _findStyle(xml, parent);
        if (next == null) break;
        cursor = next;
      }
      if (run != const RunStyle()) runs[name] = run;
      if (para != const ParaStyle()) paragraphs[name] = para;
    }
    return _OdtStyles(paragraphs: paragraphs, runs: runs);
  }

  static XmlElement? _findStyle(XmlDocument xml, String name) {
    for (final style in xml.findAllElements('style:style')) {
      if (style.getAttribute('style:name') == name) return style;
    }
    return null;
  }

  static double? _points(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    final match = RegExp(r'^(-?[\d.]+)\s*([a-z%]*)$').firstMatch(trimmed);
    if (match == null) return null;
    final n = double.tryParse(match.group(1)!);
    if (n == null) return null;
    return switch (match.group(2)) {
      'pt' => n,
      'in' => n * 72,
      'cm' => n * 28.3465,
      'mm' => n * 2.83465,
      'pc' => n * 12,
      'px' => n * 0.75,
      '%' => null,
      _ => n,
    };
  }

  static DocAlign? _align(String? value) => switch (value) {
        'center' => DocAlign.center,
        'right' || 'end' => DocAlign.right,
        'justify' => DocAlign.justify,
        'start' || 'left' => DocAlign.left,
        _ => null,
      };

  static String _alignName(DocAlign align) => switch (align) {
        DocAlign.center => 'center',
        DocAlign.right => 'right',
        DocAlign.justify => 'justify',
        DocAlign.left => 'start',
      };

  static List<int> _write(WordDocument doc) {
    final runStyles = <String, String>{};
    final paraStyles = <String, String>{};
    final body = StringBuffer();
    final automatic = StringBuffer();
    var runIndex = 0;
    var paraIndex = 0;

    String runStyle(RunStyle style) {
      final key = _runKey(style);
      final existing = runStyles[key];
      if (existing != null) return existing;
      final name = 'R${runIndex++}';
      runStyles[key] = name;
      final props = StringBuffer();
      if (style.fontFamily != null) {
        props.write(' fo:font-family="${_esc(style.fontFamily!)}"');
      }
      if (style.fontSize != null) {
        props.write(' fo:font-size="${style.fontSize!.toStringAsFixed(1)}pt"');
      }
      if (style.bold) props.write(' fo:font-weight="bold"');
      if (style.italic) props.write(' fo:font-style="italic"');
      if (style.underline) props.write(' style:text-underline-style="solid"');
      if (style.strikethrough) props.write(' style:text-line-through-style="solid"');
      if (style.superscript) props.write(' style:text-position="super"');
      if (style.subscript) props.write(' style:text-position="sub"');
      automatic.write(
        '<style:style style:name="$name" style:family="text">'
        '<style:text-properties$props/></style:style>',
      );
      return name;
    }

    String paraStyle(ParaStyle style) {
      if (style.align == null &&
          style.spaceBefore == null &&
          style.spaceAfter == null &&
          style.indentLeft == null &&
          style.indentRight == null) {
        return '';
      }
      final key = '${style.align}|${style.spaceBefore}|${style.spaceAfter}'
          '|${style.indentLeft}|${style.indentRight}';
      final existing = paraStyles[key];
      if (existing != null) return existing;
      final name = 'P${paraIndex++}';
      paraStyles[key] = name;
      final props = StringBuffer();
      if (style.align != null) {
        props.write(' fo:text-align="${_alignName(style.align!)}"');
      }
      if (style.spaceBefore != null) {
        props.write(' fo:margin-top="${style.spaceBefore!.toStringAsFixed(1)}pt"');
      }
      if (style.spaceAfter != null) {
        props.write(' fo:margin-bottom="${style.spaceAfter!.toStringAsFixed(1)}pt"');
      }
      if (style.indentLeft != null) {
        props.write(' fo:margin-left="${style.indentLeft!.toStringAsFixed(1)}pt"');
      }
      if (style.indentRight != null) {
        props.write(' fo:margin-right="${style.indentRight!.toStringAsFixed(1)}pt"');
      }
      automatic.write(
        '<style:style style:name="$name" style:family="paragraph">'
        '<style:paragraph-properties$props/></style:style>',
      );
      return name;
    }

    String paragraphXml(DocParagraph paragraph, {String tag = 'text:p'}) {
      final attrs = StringBuffer();
      final styleName = paraStyle(paragraph.style);
      if (styleName.isNotEmpty) attrs.write(' text:style-name="$styleName"');
      final heading = paragraph.style.headingLevel;
      final tagName = tag == 'text:p' && heading != null ? 'text:h' : tag;
      if (tagName == 'text:h') {
        attrs.write(' text:outline-level="${heading!.clamp(1, 6)}"');
      }
      final runs = StringBuffer();
      for (final run in paragraph.runs) {
        if (run.text.isEmpty) continue;
        final name = runStyle(run.style);
        runs.write('<text:span text:style-name="$name">${_esc(run.text)}</text:span>');
      }
      return '<$tagName$attrs>$runs</$tagName>';
    }

    for (final block in doc.blocks) {
      if (block is DocTextBlock) {
        body.write(paragraphXml(block.paragraph));
      } else if (block is DocTableBlock) {
        body.write('<table:table table:name="Table1">');
        for (final row in block.table.rows) {
          body.write('<table:table-row>');
          for (final cell in row.cells) {
            body.write('<table:table-cell>');
            for (final paragraph in cell.paragraphs) {
              body.write(paragraphXml(paragraph));
            }
            body.write('</table:table-cell>');
          }
          body.write('</table:table-row>');
        }
        body.write('</table:table>');
      }
    }

    final content = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>')
      ..write('<office:document-content '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
          'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
          'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
          'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
          'office:version="1.2"><office:automatic-styles>$automatic'
          '</office:automatic-styles><office:body><office:text>$body'
          '</office:text></office:body></office:document-content>');

    final styles = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>')
      ..write('<office:document-styles '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
          'office:version="1.2"><office:styles/></office:document-styles>');

    final meta = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>')
      ..write('<office:document-meta '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/" '
          'office:version="1.2"><office:meta>')
      ..write('<dc:title>${_esc(doc.meta.title ?? '')}</dc:title>')
      ..write('<dc:creator>${_esc(doc.meta.author ?? '')}</dc:creator>')
      ..write('</office:meta></office:document-meta>');

    final manifest = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>')
      ..write('<manifest:manifest '
          'xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" '
          'manifest:version="1.2">')
      ..write('<manifest:file-entry manifest:full-path="/" '
          'manifest:media-type="$_mimetype"/>')
      ..write('<manifest:file-entry manifest:full-path="content.xml" '
          'manifest:media-type="text/xml"/>')
      ..write('<manifest:file-entry manifest:full-path="styles.xml" '
          'manifest:media-type="text/xml"/>')
      ..write('<manifest:file-entry manifest:full-path="meta.xml" '
          'manifest:media-type="text/xml"/>')
      ..write('</manifest:manifest>');

    final zip = Archive();
    zip.addFile(_file('mimetype', _mimetype));
    zip.addFile(_file('META-INF/manifest.xml', manifest.toString()));
    zip.addFile(_file('content.xml', content.toString()));
    zip.addFile(_file('styles.xml', styles.toString()));
    zip.addFile(_file('meta.xml', meta.toString()));
    return ZipEncoder().encode(zip);
  }

  static ArchiveFile _file(String name, String content) {
    final data = Uint8List.fromList(utf8.encode(content));
    return ArchiveFile(name, data.length, data);
  }

  static String _runKey(RunStyle style) =>
      '${style.fontFamily}|${style.fontSize}|${style.bold}|${style.italic}'
      '|${style.underline}|${style.strikethrough}|${style.superscript}'
      '|${style.subscript}';

  static String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _OdtStyles {
  const _OdtStyles({required this.paragraphs, required this.runs});
  final Map<String, ParaStyle> paragraphs;
  final Map<String, RunStyle> runs;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}