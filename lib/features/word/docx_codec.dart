import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
enum DocAlign { left, center, right, justify }
enum DocList { none, bullet, ordered }
class RunStyle {
  const RunStyle({
    this.fontFamily,
    this.fontSize,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.color,
    this.highlight,
    this.superscript = false,
    this.subscript = false,
  });
  final String? fontFamily;
  final double? fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final int? color;
  final int? highlight;
  final bool superscript;
  final bool subscript;
  RunStyle mergedWith(RunStyle other) => RunStyle(
        fontFamily: other.fontFamily ?? fontFamily,
        fontSize: other.fontSize ?? fontSize,
        bold: other.bold || bold,
        italic: other.italic || italic,
        underline: other.underline || underline,
        strikethrough: other.strikethrough || strikethrough,
        color: other.color ?? color,
        highlight: other.highlight ?? highlight,
        superscript: other.superscript || superscript,
        subscript: other.subscript || subscript,
      );
  RunStyle cleared() => const RunStyle();
  bool sameAs(RunStyle other) =>
      fontFamily == other.fontFamily &&
      fontSize == other.fontSize &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      strikethrough == other.strikethrough &&
      color == other.color &&
      highlight == other.highlight;
}
class ParaStyle {
  const ParaStyle({
    this.align,
    this.spaceBefore,
    this.spaceAfter,
    this.lineHeight,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.list = DocList.none,
    this.listLevel = 0,
    this.headingLevel,
    this.shading,
  });
  final DocAlign? align;
  final double? spaceBefore;
  final double? spaceAfter;
  final double? lineHeight;
  final double? indentLeft;
  final double? indentRight;
  final double? indentFirstLine;
  final DocList list;
  final int listLevel;
  final int? headingLevel;
  final int? shading;
  ParaStyle mergedWith(ParaStyle other) => ParaStyle(
        align: other.align ?? align,
        spaceBefore: other.spaceBefore ?? spaceBefore,
        spaceAfter: other.spaceAfter ?? spaceAfter,
        lineHeight: other.lineHeight ?? lineHeight,
        indentLeft: other.indentLeft ?? indentLeft,
        indentRight: other.indentRight ?? indentRight,
        indentFirstLine: other.indentFirstLine ?? indentFirstLine,
        list: other.list == DocList.none ? list : other.list,
        listLevel: other.list == DocList.none ? listLevel : other.listLevel,
        headingLevel: other.headingLevel ?? headingLevel,
        shading: other.shading ?? shading,
      );
  ParaStyle cleared() => ParaStyle(list: list, listLevel: listLevel);
}
class DocRun {
  const DocRun(this.text, [this.style = const RunStyle()]);
  final String text;
  final RunStyle style;
  DocRun copyWith({String? text, RunStyle? style}) =>
      DocRun(text ?? this.text, style ?? this.style);
}
class DocParagraph {
  DocParagraph({List<DocRun>? runs, this.style = const ParaStyle()})
      : runs = runs ?? <DocRun>[];
  List<DocRun> runs;
  ParaStyle style;
  String get plainText => runs.map((r) => r.text).join();
  DocParagraph copy() => DocParagraph(
        runs: runs.map((r) => DocRun(r.text, r.style)).toList(),
        style: style,
      );
  void clearRuns() => runs.clear();
}
class DocTableCell {
  DocTableCell([List<DocParagraph>? paragraphs])
      : paragraphs = paragraphs ?? <DocParagraph>[];
  List<DocParagraph> paragraphs;
  int? fill;
  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}
class DocTableRow {
  DocTableRow([List<DocTableCell>? cells]) : cells = cells ?? <DocTableCell>[];
  List<DocTableCell> cells;
}
class DocTable {
  DocTable([List<DocTableRow>? rows]) : rows = rows ?? <DocTableRow>[];
  List<DocTableRow> rows;
}
sealed class DocBlock {
  DocBlock clone();
}
class DocTextBlock extends DocBlock {
  DocTextBlock(DocParagraph paragraph) : paragraph = paragraph;
  DocParagraph paragraph;
  @override
  DocBlock clone() => DocTextBlock(paragraph.copy());
}
class DocTableBlock extends DocBlock {
  DocTableBlock(this.table);
  DocTable table;
  @override
  DocBlock clone() => DocTableBlock(
        DocTable(
          table.rows
              .map((row) => DocTableRow(
                    row.cells
                        .map((cell) => DocTableCell(
                              cell.paragraphs.map((p) => p.copy()).toList(),
                            )..fill = cell.fill)
                        .toList(),
                  ))
              .toList(),
        ),
      );
}
class DocBreakBlock extends DocBlock {
  @override
  DocBlock clone() => DocBreakBlock();
}
class DocPageSetup {
  const DocPageSetup({
    this.pageWidthPt = 595,
    this.pageHeightPt = 842,
    this.marginTopPt = 72,
    this.marginBottomPt = 72,
    this.marginLeftPt = 90,
    this.marginRightPt = 90,
    this.columns = 1,
  });
  final double pageWidthPt;
  final double pageHeightPt;
  final double marginTopPt;
  final double marginBottomPt;
  final double marginLeftPt;
  final double marginRightPt;
  final int columns;
  bool get landscape => pageWidthPt > pageHeightPt;
  double get contentWidthPt =>
      (pageWidthPt - marginLeftPt - marginRightPt) / columns;
  DocPageSetup copyWith({
    double? pageWidthPt,
    double? pageHeightPt,
    double? marginTopPt,
    double? marginBottomPt,
    double? marginLeftPt,
    double? marginRightPt,
    int? columns,
  }) =>
      DocPageSetup(
        pageWidthPt: pageWidthPt ?? this.pageWidthPt,
        pageHeightPt: pageHeightPt ?? this.pageHeightPt,
        marginTopPt: marginTopPt ?? this.marginTopPt,
        marginBottomPt: marginBottomPt ?? this.marginBottomPt,
        marginLeftPt: marginLeftPt ?? this.marginLeftPt,
        marginRightPt: marginRightPt ?? this.marginRightPt,
        columns: columns ?? this.columns,
      );
  static const a4 = DocPageSetup();
  static const letter = DocPageSetup(
    pageWidthPt: 612,
    pageHeightPt: 792,
    marginTopPt: 72,
    marginBottomPt: 72,
    marginLeftPt: 72,
    marginRightPt: 72,
  );
}
class DocMeta {
  const DocMeta({this.title, this.author, this.subject, this.keywords});
  final String? title;
  final String? author;
  final String? subject;
  final String? keywords;
  DocMeta copyWith({String? title, String? author, String? subject, String? keywords}) =>
      DocMeta(
        title: title ?? this.title,
        author: author ?? this.author,
        subject: subject ?? this.subject,
        keywords: keywords ?? this.keywords,
      );
}
class WordDocument {
  WordDocument({
    List<DocBlock>? blocks,
    this.pageSetup = DocPageSetup.a4,
    this.meta = const DocMeta(),
    Map<String, Uint8List>? images,
  })  : blocks = blocks ?? <DocBlock>[],
        images = images ?? <String, Uint8List>{};
  List<DocBlock> blocks;
  DocPageSetup pageSetup;
  DocMeta meta;
  final Map<String, Uint8List> images;
  String get plainText => blocks
      .whereType<DocTextBlock>()
      .map((b) => b.paragraph.plainText)
      .join('\n');
  int get paragraphCount => blocks.whereType<DocTextBlock>().length;
  int get tableCount => blocks.whereType<DocTableBlock>().length;
  int get wordCount {
    final text = plainText;
    if (text.trim().isEmpty) return 0;
    return RegExp(r"\S+").allMatches(text).length;
  }
  int get characterCount => plainText.replaceAll('\n', '').length;
  WordDocument clone() => WordDocument(
        blocks: blocks.map((b) => b.clone()).toList(),
        pageSetup: pageSetup,
        meta: meta,
        images: Map<String, Uint8List>.from(images),
      );
}
class DocxCodec {
  const DocxCodec._();
  static Future<WordDocument> load(List<int> bytes) async =>
      DocxCodec._read(bytes);
  static Future<List<int>> save(WordDocument doc) async =>
      DocxCodec._write(doc);
  static WordDocument _read(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final parts = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile) {
        parts[file.name] = file.content is List<int>
            ? Uint8List.fromList(file.content as List<int>)
            : Uint8List(0);
      }
    }
    final docPart = parts['word/document.xml'];
    final document = WordDocument();
    if (docPart == null) return document;
    final numbering = _readNumbering(parts['word/numbering.xml']);
    final headingByStyle = _readStyleHeadings(parts['word/styles.xml']);
    final rels = _readRels(parts['word/_rels/document.xml.rels']);
    final XmlDocument xml;
    try {
      xml = XmlDocument.parse(utf8.decode(docPart, allowMalformed: true));
    } catch (_) {
      return document;
    }
    final body = xml.findAllElements('w:body').firstOrNull;
    if (body == null) return document;
    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          if (_isPageBreakOnly(child)) {
            document.blocks.add(DocBreakBlock());
          } else {
            document.blocks.add(
              DocTextBlock(_readParagraph(child, numbering, headingByStyle)),
            );
          }
        case 'tbl':
          final table = _readTable(child);
          if (table != null) document.blocks.add(DocTableBlock(table));
        case 'sectPr':
          final setup = _readSection(child);
          if (setup != null) document.pageSetup = setup;
      }
    }
    for (final entry in rels.entries) {
      final target = entry.value;
      if (target.startsWith('media/')) {
        final media = parts['word/$target'];
        if (media != null) document.images[entry.key] = media;
      }
    }
    document.meta = _readCore(parts['docProps/core.xml']);
    return document;
  }
  static bool _isPageBreakOnly(XmlElement element) {
    var hasBreak = false;
    var hasContent = false;
    for (final child in element.childElements) {
      if (child.name.local == 'pPr') continue;
      if (child.name.local != 'r') continue;
      for (final part in child.childElements) {
        switch (part.name.local) {
          case 'br':
            if (part.getAttribute('w:type') == 'page') {
              hasBreak = true;
            }
          case 't':
            if (part.innerText.trim().isNotEmpty) hasContent = true;
        }
      }
    }
    return hasBreak && !hasContent;
  }

  static DocParagraph _readParagraph(
    XmlElement element,
    Map<String, DocList> numbering,
    Map<String, int> headingByStyle,
  ) {
    final paragraph = DocParagraph();
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'pPr':
          paragraph.style = _readParaStyle(child, numbering, headingByStyle);
        case 'r':
          final run = _readRun(child);
          if (run != null && run.text.isNotEmpty) paragraph.runs.add(run);
      }
    }
    if (paragraph.runs.isEmpty) paragraph.runs.add(const DocRun(''));
    return paragraph;
  }
  static DocRun? _readRun(XmlElement element) {
    final buffer = StringBuffer();
    var style = const RunStyle();
    var found = false;
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 't':
          buffer.write(child.innerText);
          found = true;
        case 'tab':
          buffer.write('\t');
          found = true;
        case 'br':
          if (child.getAttribute('w:type') == 'page') {
            buffer.write('\f');
          } else {
            buffer.write('\n');
          }
          found = true;
        case 'rPr':
          style = _readRunStyle(child);
      }
    }
    if (!found) return null;
    return DocRun(buffer.toString(), style);
  }
  static RunStyle _readRunStyle(XmlElement element) {
    String? family;
    double? size;
    var bold = false;
    var italic = false;
    var underline = false;
    var strike = false;
    int? color;
    int? highlight;
    var super_ = false;
    var sub_ = false;
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'rFonts':
          family = child.getAttribute('w:ascii') ?? family;
        case 'sz':
          final raw = double.tryParse(child.getAttribute('w:val') ?? '');
          if (raw != null) size = raw / 2;
        case 'b':
          final v = child.getAttribute('w:val');
          bold = v == null || v == '1' || v == 'true';
        case 'i':
          final v = child.getAttribute('w:val');
          italic = v == null || v == '1' || v == 'true';
        case 'u':
          final v = child.getAttribute('w:val');
          underline = v != null && v != 'none';
        case 'strike':
          final v = child.getAttribute('w:val');
          strike = v == null || v == '1' || v == 'true';
        case 'color':
          color = _parseHexColor(child.getAttribute('w:val'));
        case 'highlight':
          highlight = _parseHexColor(
            _highlightMap[child.getAttribute('w:val')] ?? 'FFFF00',
          );
        case 'vertAlign':
          final v = child.getAttribute('w:val');
          super_ = v == 'superscript';
          sub_ = v == 'subscript';
      }
    }
    return RunStyle(
      fontFamily: family,
      fontSize: size,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strike,
      color: color,
      highlight: highlight,
      superscript: super_,
      subscript: sub_,
    );
  }
  static ParaStyle _readParaStyle(
    XmlElement element,
    Map<String, DocList> numbering,
    Map<String, int> headingByStyle,
  ) {
    DocAlign? align;
    double? before;
    double? after;
    double? line;
    double? left;
    double? right;
    double? firstLine;
    var list = DocList.none;
    var level = 0;
    int? heading;
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'pStyle':
          heading = headingByStyle[child.getAttribute('w:val') ?? ''];
        case 'jc':
          align = switch (child.getAttribute('w:val')) {
            'center' => DocAlign.center,
            'right' || 'end' => DocAlign.right,
            'both' || 'distribute' => DocAlign.justify,
            _ => DocAlign.left,
          };
        case 'spacing':
          before = _parseTwips(child.getAttribute('w:before'));
          after = _parseTwips(child.getAttribute('w:after'));
          final rawLine = child.getAttribute('w:line');
          if (rawLine != null) {
            final v = int.tryParse(rawLine);
            if (v != null) {
              line = child.getAttribute('w:lineRule') == 'exact'
                  ? v / 20
                  : v / 240;
            }
          }
        case 'ind':
          left = _parseTwips(child.getAttribute('w:left') ??
              child.getAttribute('w:start'));
          right = _parseTwips(child.getAttribute('w:right') ??
              child.getAttribute('w:end'));
          final hanging = child.getAttribute('w:hanging');
          firstLine = hanging != null
              ? -(_parseTwips(hanging) ?? 0)
              : _parseTwips(child.getAttribute('w:firstLine'));
        case 'numPr':
          level = int.tryParse(
                child.findElements('w:ilvl').firstOrNull?.getAttribute('w:val') ?? '',
              ) ??
              0;
          final numId =
              child.findElements('w:numId').firstOrNull?.getAttribute('w:val');
          list = numbering[numId] ?? DocList.bullet;
      }
    }
    return ParaStyle(
      align: align,
      spaceBefore: before,
      spaceAfter: after,
      lineHeight: line,
      indentLeft: left,
      indentRight: right,
      indentFirstLine: firstLine,
      list: list,
      listLevel: level,
      headingLevel: heading,
    );
  }
  static DocTable? _readTable(XmlElement element) {
    final table = DocTable();
    for (final rowElement in element.findElements('w:tr')) {
      final row = DocTableRow();
      for (final cellElement in rowElement.findElements('w:tc')) {
        final cell = DocTableCell();
        for (final p in cellElement.findElements('w:p')) {
          cell.paragraphs.add(_readParagraph(p, const {}, const {}));
        }
        if (cell.paragraphs.isEmpty) cell.paragraphs.add(DocParagraph());
        row.cells.add(cell);
      }
      if (row.cells.isNotEmpty) table.rows.add(row);
    }
    return table.rows.isEmpty ? null : table;
  }
  static DocPageSetup? _readSection(XmlElement element) {
    double? width;
    double? height;
    double? top;
    double? bottom;
    double? left;
    double? right;
    var columns = 1;
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'pgSz':
          width = _emuToPoints(child.getAttribute('w:w'));
          height = _emuToPoints(child.getAttribute('w:h'));
        case 'pgMar':
          top = _twipsToPoints(child.getAttribute('w:top'));
          bottom = _twipsToPoints(child.getAttribute('w:bottom'));
          left = _twipsToPoints(child.getAttribute('w:left') ??
              child.getAttribute('w:start'));
          right = _twipsToPoints(child.getAttribute('w:right') ??
              child.getAttribute('w:end'));
        case 'cols':
          columns = int.tryParse(child.getAttribute('w:num') ?? '') ?? 1;
      }
    }
    return DocPageSetup(
      pageWidthPt: width ?? DocPageSetup.a4.pageWidthPt,
      pageHeightPt: height ?? DocPageSetup.a4.pageHeightPt,
      marginTopPt: top ?? DocPageSetup.a4.marginTopPt,
      marginBottomPt: bottom ?? DocPageSetup.a4.marginBottomPt,
      marginLeftPt: left ?? DocPageSetup.a4.marginLeftPt,
      marginRightPt: right ?? DocPageSetup.a4.marginRightPt,
      columns: columns < 1 ? 1 : columns,
    );
  }
  static Map<String, DocList> _readNumbering(Uint8List? bytes) {
    final out = <String, DocList>{};
    if (bytes == null) return out;
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      final abstractFormats = <String, DocList>{};
      for (final abstractNum in xml.findAllElements('w:abstractNum')) {
        final id = abstractNum.getAttribute('w:w:abstractNumId');
        if (id == null) continue;
        final level = abstractNum.findElements('w:lvl').firstOrNull;
        final fmt = level?.findElements('w:numFmt').firstOrNull
                ?.getAttribute('w:val') ??
            'bullet';
        abstractFormats[id] =
            fmt == 'bullet' ? DocList.bullet : DocList.ordered;
      }
      for (final num in xml.findAllElements('w:num')) {
        final numId = num.getAttribute('w:w:numId');
        final abstractId = num
            .findElements('w:abstractNumId')
            .firstOrNull
            ?.getAttribute('w:val')
            ;
        if (numId != null && abstractId != null) {
          out[numId] = abstractFormats[abstractId] ?? DocList.bullet;
        }
      }
    } catch (_) {}
    return out;
  }
  static Map<String, int> _readStyleHeadings(Uint8List? bytes) {
    final out = <String, int>{};
    if (bytes == null) return out;
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      for (final style in xml.findAllElements('w:style')) {
        final id = style.getAttribute('w:w:styleId');
        if (id == null) continue;
        final outline = style
            .findElements('w:pPr')
            .firstOrNull
            ?.findElements('w:outlineLvl')
            .firstOrNull
            ?.getAttribute('w:val')
            ;
        if (outline != null) {
          out[id] = int.tryParse(outline) ?? 0;
          continue;
        }
        if (RegExp(r'^Heading[1-9]$', caseSensitive: false).hasMatch(id)) {
          out[id] = int.tryParse(id.replaceAll(RegExp('[^0-9]'), '')) ?? 1 - 1;
        }
      }
    } catch (_) {}
    return out;
  }
  static Map<String, String> _readRels(Uint8List? bytes) {
    final out = <String, String>{};
    if (bytes == null) return out;
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      for (final rel in xml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) out[id] = target;
      }
    } catch (_) {}
    return out;
  }
  static DocMeta _readCore(Uint8List? bytes) {
    if (bytes == null) return const DocMeta();
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      String? pick(String name) => xml
          .findAllElements(name)
          .firstOrNull
          ?.innerText
          .trim();
      return DocMeta(
        title: pick('dc:title'),
        author: pick('dc:creator'),
        subject: pick('dc:subject'),
        keywords: pick('cp:keywords'),
      );
    } catch (_) {
      return const DocMeta();
    }
  }
  static List<int> _write(WordDocument doc) {
    final archive = Archive();
    final mediaIds = <String, String>{};
    for (final entry in doc.images.entries) {
      final name = 'image${mediaIds.length + 1}${_extensionFor(entry.value)}';
      mediaIds[entry.key] = name;
      archive.addFile(
        ArchiveFile('word/media/$name', entry.value.length, entry.value),
      );
    }
    archive.addFile(
      _bytes('[Content_Types].xml', _contentTypes(mediaIds)),
    );
    archive.addFile(_bytes('_rels/.rels', _rootRels));
    archive.addFile(_bytes('docProps/core.xml', _coreXml(doc.meta)));
    archive.addFile(_bytes('docProps/app.xml', _appXml));
    archive.addFile(_bytes('word/styles.xml', _stylesXml));
    archive.addFile(_bytes('word/numbering.xml', _numberingXml));
    archive.addFile(
      _bytes(
        'word/_rels/document.xml.rels',
        _documentRels(mediaIds),
      ),
    );
    archive.addFile(
      _bytes('word/document.xml', _documentXml(doc, mediaIds)),
    );
    final encoded = ZipEncoder().encode(archive);
    return encoded ?? const <int>[];
  }
  static ArchiveFile _bytes(String name, String content) {
    final data = utf8.encode(content);
    return ArchiveFile(name, data.length, data);
  }
  static String _extensionFor(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return '.png';
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpeg';
    if (bytes.length > 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return '.gif';
    }
    return '.png';
  }
  static String _contentTypes(Map<String, String> mediaIds) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Default Extension="png" ContentType="image/png"/>')
      ..write('<Default Extension="jpeg" ContentType="image/jpeg"/>')
      ..write('<Default Extension="gif" ContentType="image/gif"/>')
      ..write('<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>')
      ..write('<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>')
      ..write('<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>')
      ..write('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>')
      ..write('<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>')
      ..write('</Types>');
    return buffer.toString();
  }
  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';
  static String _documentRels(Map<String, String> mediaIds) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
      ..write('<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>');
    var index = 1;
    for (final name in mediaIds.values) {
      buffer.write(
        '<Relationship Id="rIdImg$index" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="media/$name"/>',
      );
      index++;
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }
  static const _appXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
      '<Application>OpenFiles</Application></Properties>';
  static String _coreXml(DocMeta meta) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'cp:coreProperties',
      attributes: {
        'xmlns:cp': 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties',
        'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
        'xmlns:dcterms': 'http://purl.org/dc/terms/',
        'xmlns:dcmitype': 'http://purl.org/dc/dcmitype/',
        'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
      },
      nest: () {
        b.element('dc:title', nest: meta.title ?? '');
        b.element('dc:subject', nest: meta.subject ?? '');
        b.element('dc:creator', nest: meta.author ?? 'OpenFiles');
        b.element('cp:keywords', nest: meta.keywords ?? '');
        b.element('dcterms:created', attributes: {'xsi:type': 'dcterms:W3CDTF'},
            nest: DateTime.now().toUtc().toIso8601String());
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String get _stylesXml {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'w:styles',
      attributes: {'xmlns:w': _nsW},
      nest: () {
        for (var level = 0; level < 6; level++) {
          b.element(
            'w:style',
            attributes: {'w:type': 'paragraph', 'w:styleId': 'Heading${level + 1}'},
            nest: () {
              b.element('w:name', attributes: {'w:val': 'heading ${level + 1}'});
              b.element(
                'w:pPr',
                nest: () {
                  b.element('w:keepNext');
                  b.element('w:outlineLvl', attributes: {'w:val': '$level'});
                  b.element('w:spacing', attributes: {
                    'w:before': '${(18 - level * 2) * 20}',
                    'w:after': '120',
                  });
                },
              );
              b.element(
                'w:rPr',
                nest: () {
                  b.element('w:b');
                  b.element(
                    'w:sz',
                    attributes: {'w:val': '${(32 - level * 2) * 2}'},
                  );
                },
              );
            },
          );
        }
        b.element(
          'w:style',
          attributes: {'w:type': 'paragraph', 'w:styleId': 'ListParagraph'},
          nest: () {
            b.element('w:name', attributes: {'w:val': 'List Paragraph'});
            b.element(
              'w:pPr',
              nest: () => b.element('w:ind', attributes: {'w:left': '720'}),
            );
          },
        );
        b.element(
          'w:style',
          attributes: {'w:type': 'paragraph', 'w:styleId': 'Normal', 'w:default': '1'},
          nest: () {
            b.element('w:name', attributes: {'w:val': 'Normal'});
          },
        );
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String get _numberingXml {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'w:numbering',
      attributes: {'xmlns:w': _nsW},
      nest: () {
        for (final entry in const [(1, 'bullet'), (2, 'decimal')]) {
          b.element(
            'w:abstractNum',
            attributes: {'w:abstractNumId': '${entry.$1}'},
            nest: () {
              for (var level = 0; level < 9; level++) {
                b.element('w:lvl', attributes: {'w:ilvl': '$level'}, nest: () {
                  b.element('w:start', attributes: {'w:val': '1'});
                  b.element('w:numFmt', attributes: {'w:val': entry.$2});
                  b.element(
                    'w:lvlText',
                    attributes: {
                      'w:val': entry.$2 == 'bullet' ? '•' : '%${level + 1}.',
                    },
                  );
                  b.element(
                    'w:pPr',
                    nest: () => b.element(
                      'w:ind',
                      attributes: {
                        'w:left': '${720 * (level + 1)}',
                        'w:hanging': '360',
                      },
                    ),
                  );
                });
              }
            },
          );
        }
        b.element(
          'w:num',
          attributes: {'w:numId': '1'},
          nest: () =>
              b.element('w:abstractNumId', attributes: {'w:val': '1'}),
        );
        b.element(
          'w:num',
          attributes: {'w:numId': '2'},
          nest: () =>
              b.element('w:abstractNumId', attributes: {'w:val': '2'}),
        );
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _documentXml(WordDocument doc, Map<String, String> mediaIds) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'w:document',
      attributes: {
        'xmlns:w': _nsW,
        'xmlns:r': _nsR,
        'xmlns:wp': _nsWp,
        'xmlns:a': _nsA,
        'xmlns:pic': _nsPic,
      },
      nest: () {
        b.element('w:body', nest: () {
          var imageCounter = 0;
          var usedBullets = false;
          var usedOrdered = false;
          for (final block in doc.blocks) {
            switch (block) {
              case DocTextBlock(:final paragraph):
                if (paragraph.style.list == DocList.bullet) usedBullets = true;
                if (paragraph.style.list == DocList.ordered) usedOrdered = true;
                _writeParagraph(b, paragraph, mediaIds, () => 'rIdImg${++imageCounter}');
              case DocTableBlock(:final table):
                _writeTable(b, table);
              case DocBreakBlock():
                b.element('w:p', nest: () => b.element('w:r', nest: () {
                  b.element('w:br', attributes: {'w:type': 'page'});
                }));
            }
          }
          b.element('w:sectPr', nest: () {
            b.element('w:pgSz', attributes: {
              'w:w': '${(doc.pageSetup.pageWidthPt * 20).round()}',
              'w:h': '${(doc.pageSetup.pageHeightPt * 20).round()}',
              if (doc.pageSetup.landscape) 'w:orient': 'landscape',
            });
            b.element('w:pgMar', attributes: {
              'w:top': '${(doc.pageSetup.marginTopPt * 20).round()}',
              'w:bottom': '${(doc.pageSetup.marginBottomPt * 20).round()}',
              'w:left': '${(doc.pageSetup.marginLeftPt * 20).round()}',
              'w:right': '${(doc.pageSetup.marginRightPt * 20).round()}',
            });
            if (doc.pageSetup.columns > 1) {
              b.element('w:cols', attributes: {'w:num': '${doc.pageSetup.columns}'});
            }
          });
          if (usedBullets || usedOrdered) {}
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static void _writeParagraph(
    XmlBuilder b,
    DocParagraph paragraph,
    Map<String, String> mediaIds,
    String Function() nextImageId,
  ) {
    b.element('w:p', nest: () {
      final pStyle = paragraph.style;
      if (pStyle.headingLevel != null ||
          pStyle.align != null ||
          pStyle.list != DocList.none ||
          pStyle.spaceBefore != null ||
          pStyle.spaceAfter != null ||
          pStyle.indentLeft != null ||
          pStyle.indentRight != null ||
          pStyle.indentFirstLine != null) {
        b.element('w:pPr', nest: () {
          if (pStyle.headingLevel != null) {
            b.element('w:pStyle', attributes: {
              'w:val': 'Heading${(pStyle.headingLevel! + 1).clamp(1, 6)}',
            });
          }
          if (pStyle.list != DocList.none) {
            b.element('w:numPr', nest: () {
              b.element('w:ilvl', attributes: {'w:val': '${pStyle.listLevel}'});
              b.element('w:numId', attributes: {
                'w:val': pStyle.list == DocList.bullet ? '1' : '2',
              });
            });
          }
          if (pStyle.spaceBefore != null || pStyle.spaceAfter != null) {
            b.element('w:spacing', attributes: {
              if (pStyle.spaceBefore != null)
                'w:before': '${(pStyle.spaceBefore! * 20).round()}',
              if (pStyle.spaceAfter != null)
                'w:after': '${(pStyle.spaceAfter! * 20).round()}',
              if (pStyle.lineHeight != null)
                'w:line': '${(pStyle.lineHeight! * 240).round()}',
            });
          }
          if (pStyle.indentLeft != null ||
              pStyle.indentRight != null ||
              pStyle.indentFirstLine != null) {
            b.element('w:ind', attributes: {
              if (pStyle.indentLeft != null)
                'w:left': '${(pStyle.indentLeft! * 20).round()}',
              if (pStyle.indentRight != null)
                'w:right': '${(pStyle.indentRight! * 20).round()}',
              if (pStyle.indentFirstLine != null && pStyle.indentFirstLine! >= 0)
                'w:firstLine': '${(pStyle.indentFirstLine! * 20).round()}',
              if (pStyle.indentFirstLine != null && pStyle.indentFirstLine! < 0)
                'w:hanging': '${(-pStyle.indentFirstLine! * 20).round()}',
            });
          }
          if (pStyle.align != null) {
            b.element('w:jc', attributes: {
              'w:val': switch (pStyle.align!) {
                DocAlign.center => 'center',
                DocAlign.right => 'right',
                DocAlign.justify => 'both',
                DocAlign.left => 'left',
              },
            });
          }
        });
      }
      for (final run in paragraph.runs) {
        _writeRun(b, run, mediaIds, nextImageId);
      }
      if (paragraph.runs.isEmpty) {
        b.element('w:r', nest: () => b.element('w:t', nest: ''));
      }
    });
  }
  static void _writeRun(
    XmlBuilder b,
    DocRun run,
    Map<String, String> mediaIds,
    String Function() nextImageId,
  ) {
    final style = run.style;
    final needsRPr = style.fontFamily != null ||
        style.fontSize != null ||
        style.bold ||
        style.italic ||
        style.underline ||
        style.strikethrough ||
        style.color != null ||
        style.highlight != null ||
        style.superscript ||
        style.subscript;
    if (run.text.startsWith('\f')) {
      b.element('w:r', nest: () {
        b.element('w:br', attributes: {'w:type': 'page'});
      });
    }
    final text = run.text.replaceAll('\f', '');
    if (text.isEmpty && !needsRPr) return;
    b.element('w:r', nest: () {
      if (needsRPr) {
        b.element('w:rPr', nest: () {
          if (style.fontFamily != null) {
            b.element('w:rFonts', attributes: {
              'w:ascii': style.fontFamily!,
              'w:hAnsi': style.fontFamily!,
            });
          }
          if (style.bold) b.element('w:b');
          if (style.italic) b.element('w:i');
          if (style.underline) b.element('w:u', attributes: {'w:val': 'single'});
          if (style.strikethrough) b.element('w:strike');
          if (style.color != null) {
            b.element('w:color', attributes: {'w:val': _hex(style.color!)});
          }
          if (style.highlight != null) {
            b.element('w:highlight', attributes: {'w:val': 'yellow'});
          }
          if (style.fontSize != null) {
            b.element('w:sz', attributes: {'w:val': '${(style.fontSize! * 2).round()}'});
          }
          if (style.superscript) {
            b.element('w:vertAlign', attributes: {'w:val': 'superscript'});
          }
          if (style.subscript) {
            b.element('w:vertAlign', attributes: {'w:val': 'subscript'});
          }
        });
      }
      final segments = text.split('\t');
      for (var i = 0; i < segments.length; i++) {
        if (i > 0) b.element('w:tab');
        final piece = segments[i];
        final lines = piece.split('\n');
        for (var j = 0; j < lines.length; j++) {
          if (j > 0) b.element('w:br');
          if (lines[j].isNotEmpty) {
            b.element(
              'w:t',
              attributes: {'xml:space': 'preserve'},
              nest: lines[j],
            );
          }
        }
      }
    });
  }
  static void _writeTable(XmlBuilder b, DocTable table) {
    final columns = table.rows.fold<int>(0, (acc, r) => r.cells.length > acc ? r.cells.length : acc);
    if (columns == 0) return;
    b.element('w:tbl', nest: () {
      b.element('w:tblPr', nest: () {
        b.element('w:tblW', attributes: {'w:w': '0', 'w:type': 'auto'});
        b.element('w:tblBorders', nest: () {
          for (final edge in const ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
            b.element('w:$edge', attributes: {
              'w:val': 'single',
              'w:sz': '4',
              'w:space': '0',
              'w:color': 'B8B0A4',
            });
          }
        });
      });
      b.element('w:tblGrid', nest: () {
        for (var i = 0; i < columns; i++) {
          b.element('w:gridCol', attributes: {'w:w': '2000'});
        }
      });
      for (final row in table.rows) {
        b.element('w:tr', nest: () {
          for (var i = 0; i < columns; i++) {
            b.element('w:tc', nest: () {
              b.element('w:tcPr', nest: () {
                b.element('w:tcW', attributes: {'w:w': '2000', 'w:type': 'dxa'});
              });
              final cell = i < row.cells.length ? row.cells[i] : DocTableCell();
              for (final paragraph in cell.paragraphs) {
                _writeParagraph(b, paragraph, const {}, () => '');
              }
            });
          }
        });
      }
    });
  }
  static const _nsW =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _nsWp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
  static const _nsA =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _nsPic =
      'http://schemas.openxmlformats.org/drawingml/2006/picture';
  static const _highlightMap = {
    'yellow': 'FFFF00',
    'green': '00FF00',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'blue': '0000FF',
    'red': 'FF0000',
    'darkBlue': '000080',
    'darkCyan': '008080',
    'darkGreen': '008000',
    'darkMagenta': '800080',
    'darkRed': '800000',
    'darkYellow': '808000',
    'darkGray': '808080',
    'lightGray': 'C0C0C0',
    'black': '000000',
    'white': 'FFFFFF',
  };
  static double? _parseTwips(String? value) {
    final v = double.tryParse(value ?? '');
    return v == null ? null : v / 20;
  }
  static double? _twipsToPoints(String? value) {
    final v = double.tryParse(value ?? '');
    return v == null ? null : v / 20;
  }
  static double? _emuToPoints(String? value) {
    final v = double.tryParse(value ?? '');
    return v == null ? null : v / 12700;
  }
  static int? _parseHexColor(String? value) {
    if (value == null || value.length < 6) return null;
    if (value == 'auto') return null;
    final parsed = int.tryParse(value.substring(0, 6), radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
  static String _hex(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
}
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}