import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
enum SlideShape {
  rectangle,
  roundedRect,
  ellipse,
  triangle,
  line,
  rightArrow,
  star,
  hexagon,
  diamond,
  chevron,
  callout,
}
enum SlideTransition {
  none,
  fade,
  push,
  wipe,
  split,
  cover,
  reveal,
  cut,
  dissolve,
  zoom,
  flip,
  gallery,
  cube,
  doors,
  checker,
  blinds,
  clock,
  ripple,
  honeycomb,
  glitter,
  vortex,
  shred,
  switchMode,
  wind,
  prestige,
  fracture,
  curtains,
  fallOver,
  drape,
  airplane,
  origami,
  pageCurl,
  shape,
  unCover,
  randomBars,
  pan,
  ferris,
  conveyor,
  rotate,
  window,
  orbit,
  flyThrough,
  morph,
}
enum SlideTextAlign { left, center, right, justify }
enum SlideVAlign { top, middle, bottom }
class SlideTextStyle {
  const SlideTextStyle({
    this.fontFamily,
    this.fontSize = 18,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color = 0xFF2B2521,
    this.align = SlideTextAlign.left,
    this.valign = SlideVAlign.top,
  });
  final String? fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final int color;
  final SlideTextAlign align;
  final SlideVAlign valign;
  SlideTextStyle copyWith({
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    int? color,
    SlideTextAlign? align,
    SlideVAlign? valign,
  }) =>
      SlideTextStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        color: color ?? this.color,
        align: align ?? this.align,
        valign: valign ?? this.valign,
      );
}
sealed class SlideElement {
  String id = '';
  double x = 0;
  double y = 0;
  double w = 100;
  double h = 60;
  double rotation = 0;
}
class SlideText extends SlideElement {
  String text = '';
  SlideTextStyle style = const SlideTextStyle();
  bool isTitle = false;
  SlideText clone() {
    final copy = SlideText()..text = text;
    return copy
      ..style = style
      ..isTitle = isTitle
      ..id = id
      ..x = x
      ..y = y
      ..w = w
      ..h = h
      ..rotation = rotation;
  }
}
class SlideShapeEl extends SlideElement {
  SlideShape shape = SlideShape.rectangle;
  int fill = 0xFFC08163;
  int line = 0x00000000;
  double lineWidth = 0;
  String text = '';
  SlideTextStyle style = const SlideTextStyle();
  SlideShapeEl clone() {
    final copy = SlideShapeEl()..shape = shape;
    return copy
      ..fill = fill
      ..line = line
      ..lineWidth = lineWidth
      ..text = text
      ..style = style
      ..id = id
      ..x = x
      ..y = y
      ..w = w
      ..h = h
      ..rotation = rotation;
  }
}
class SlidePicture extends SlideElement {
  String mediaId;
  SlidePicture({required this.bytes, required this.mediaId});
  final Uint8List bytes;
  SlidePicture clone() {
    final copy = SlidePicture(bytes: bytes, mediaId: mediaId);
    return copy
      ..x = x
      ..y = y
      ..w = w
      ..h = h
      ..rotation = rotation;
  }
}
class SlideTableEl extends SlideElement {
  List<List<String>> rows = [];
  SlideTableEl clone() {
    final copy = SlideTableEl()..rows = rows.map((r) => List.of(r)).toList();
    return copy
      ..id = id
      ..x = x
      ..y = y
      ..w = w
      ..h = h
      ..rotation = rotation;
  }
}
class Slide {
  final List<SlideElement> elements = [];
  String notes = '';
  SlideTransition transition = SlideTransition.none;
  double transitionDuration = 0.7;
  bool advanceOnClick = true;
  double advanceAfterSeconds = 0;
  int? background;
  String get titleText {
    for (final element in elements) {
      if (element is SlideText && element.isTitle && element.text.isNotEmpty) {
        return element.text;
      }
    }
    for (final element in elements) {
      if (element is SlideText && element.text.isNotEmpty) return element.text;
    }
    return '';
  }
  Slide clone() => Slide()
    ..elements.addAll(elements.map(_cloneElement))
    ..notes = notes
    ..transition = transition
    ..transitionDuration = transitionDuration
    ..advanceOnClick = advanceOnClick
    ..advanceAfterSeconds = advanceAfterSeconds
    ..background = background;
  static SlideElement _cloneElement(SlideElement element) => switch (element) {
        final SlideText value => value.clone(),
        final SlideShapeEl value => value.clone(),
        final SlidePicture value => value.clone(),
        final SlideTableEl value => value.clone(),
      };
}
class SlideDeck {
  SlideDeck({List<Slide>? slides, this.widthPt = 960, this.heightPt = 540})
      : slides = slides ?? <Slide>[];
  final List<Slide> slides;
  double widthPt;
  double heightPt;
  String? title;
  String? author;
}
const Map<String, SlideShape> _shapeNames = {
  'rect': SlideShape.rectangle,
  'roundRect': SlideShape.roundedRect,
  'ellipse': SlideShape.ellipse,
  'triangle': SlideShape.triangle,
  'line': SlideShape.line,
  'rightArrow': SlideShape.rightArrow,
  'star5': SlideShape.star,
  'hexagon': SlideShape.hexagon,
  'diamond': SlideShape.diamond,
  'chevron': SlideShape.chevron,
  'wedgeRoundRectCallout': SlideShape.callout,
};
const Map<SlideShape, String> _shapePrst = {
  SlideShape.rectangle: 'rect',
  SlideShape.roundedRect: 'roundRect',
  SlideShape.ellipse: 'ellipse',
  SlideShape.triangle: 'triangle',
  SlideShape.line: 'line',
  SlideShape.rightArrow: 'rightArrow',
  SlideShape.star: 'star5',
  SlideShape.hexagon: 'hexagon',
  SlideShape.diamond: 'diamond',
  SlideShape.chevron: 'chevron',
  SlideShape.callout: 'wedgeRoundRectCallout',
};
const Map<String, SlideTransition> _transitionNames = {
  'fade': SlideTransition.fade,
  'push': SlideTransition.push,
  'wipe': SlideTransition.wipe,
  'split': SlideTransition.split,
  'cover': SlideTransition.cover,
  'reveal': SlideTransition.reveal,
  'cut': SlideTransition.cut,
  'dissolve': SlideTransition.dissolve,
  'zoom': SlideTransition.zoom,
  'flip': SlideTransition.flip,
  'gallery': SlideTransition.gallery,
  'cube': SlideTransition.cube,
  'doors': SlideTransition.doors,
  'checker': SlideTransition.checker,
  'blinds': SlideTransition.blinds,
  'clock': SlideTransition.clock,
  'ripple': SlideTransition.ripple,
  'honeycomb': SlideTransition.honeycomb,
  'glitter': SlideTransition.glitter,
  'vortex': SlideTransition.vortex,
  'shred': SlideTransition.shred,
  'switch': SlideTransition.switchMode,
  'wind': SlideTransition.wind,
  'prestige': SlideTransition.prestige,
  'fracture': SlideTransition.fracture,
  'curtains': SlideTransition.curtains,
  'fallOver': SlideTransition.fallOver,
  'drape': SlideTransition.drape,
  'airplane': SlideTransition.airplane,
  'origami': SlideTransition.origami,
  'pageCurl': SlideTransition.pageCurl,
  'shape': SlideTransition.shape,
  'uncover': SlideTransition.unCover,
  'randomBar': SlideTransition.randomBars,
  'pan': SlideTransition.pan,
  'ferris': SlideTransition.ferris,
  'conveyor': SlideTransition.conveyor,
  'rotate': SlideTransition.rotate,
  'window': SlideTransition.window,
  'orbit': SlideTransition.orbit,
  'flythrough': SlideTransition.flyThrough,
  'morph': SlideTransition.morph,
};
class PptxCodec {
  const PptxCodec._();
  static Future<SlideDeck> load(List<int> bytes) async => _read(bytes);
  static Future<List<int>> save(SlideDeck deck) async => _write(deck);
  static SlideDeck _read(List<int> bytes) {
    final deck = SlideDeck();
    final archive = ZipDecoder().decodeBytes(bytes);
    final parts = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile) {
        parts[file.name] = Uint8List.fromList(file.content as List<int>);
      }
    }
    final presentation = parts['ppt/presentation.xml'];
    if (presentation != null) {
      try {
        final doc = XmlDocument.parse(utf8.decode(presentation, allowMalformed: true));
        final size = doc.findAllElements('p:sldSz').firstOrNull;
        final cx = double.tryParse(size?.getAttribute('cx') ?? '');
        final cy = double.tryParse(size?.getAttribute('cy') ?? '');
        if (cx != null && cy != null) {
          deck
            ..widthPt = cx / 12700
            ..heightPt = cy / 12700;
        }
      } catch (_) {}
    }
    final slideNames = parts.keys
        .where((k) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(k))
        .toList()
      ..sort((a, b) => _slideIndex(a).compareTo(_slideIndex(b)));
    for (final name in slideNames) {
      final relsName = 'ppt/slides/_rels/${name.split('/').last}.rels';
      final rels = _readRels(parts[relsName]);
      deck.slides.add(_readSlide(parts[name], parts, rels));
    }
    if (deck.slides.isEmpty) deck.slides.add(Slide());
    deck.title = _firstText(parts['docProps/core.xml'], 'dc:title');
    deck.author = _firstText(parts['docProps/core.xml'], 'dc:creator');
    return deck;
  }
  static int _slideIndex(String path) =>
      int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(path)?.group(1) ?? '') ?? 0;
  static Slide _readSlide(
    Uint8List? bytes,
    Map<String, Uint8List> parts,
    Map<String, String> rels,
  ) {
    final slide = Slide();
    if (bytes == null) return slide;
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return slide;
    }
    final tree = doc.findAllElements('p:spTree').firstOrNull;
    if (tree == null) return slide;
    var counter = 1;
    for (final node in tree.childElements) {
      switch (node.name.local) {
        case 'sp':
          final element = _readShape(node, 'sp$counter', slide);
          if (element != null) slide.elements.add(element);
          counter++;
        case 'pic':
          final element = _readPicture(node, parts, rels, 'pic$counter');
          if (element != null) slide.elements.add(element);
          counter++;
        case 'graphicFrame':
          final element = _readGraphicFrame(node, 'gf$counter');
          if (element != null) slide.elements.add(element);
          counter++;
      }
    }
    final transition = doc.findAllElements('p:transition').firstOrNull;
    if (transition != null) {
      for (final child in transition.childElements) {
        final mapped = _transitionNames[child.name.local];
        if (mapped != null) {
          slide.transition = mapped;
          break;
        }
      }
      final dur = transition.getAttribute('spd');
      if (dur != null) {
        slide.transitionDuration = switch (dur) {
          'slow' => 1.4,
          'fast' => 0.4,
          _ => 0.7,
        };
      }
    }
    final notesRef = rels.values.firstWhere(
      (v) => v.startsWith('../notesSlides/'),
      orElse: () => '',
    );
    if (notesRef.isNotEmpty) {
      final notesPath = 'ppt/notesSlides/${notesRef.split('/').last}';
      final notesBytes = parts[notesPath];
      if (notesBytes != null) {
        try {
          final notesDoc =
              XmlDocument.parse(utf8.decode(notesBytes, allowMalformed: true));
          slide.notes = notesDoc
              .findAllElements('a:t')
              .map((e) => e.innerText)
              .join(' ')
              .trim();
        } catch (_) {}
      }
    }
    return slide;
  }
  static SlideElement? _readShape(XmlElement node, String id, Slide slide) {
    final xfrm = node.findAllElements('a:xfrm').firstOrNull;
    final off = xfrm?.findElements('a:off').firstOrNull;
    final ext = xfrm?.findElements('a:ext').firstOrNull;
    final prst = node.findAllElements('a:prstGeom').firstOrNull?.getAttribute('prst');
    final textBody = node.findElements('p:txBody').firstOrNull;
    final text = textBody?.findAllElements('a:t').map((e) => e.innerText).join() ?? '';
    final style = _readTextStyle(textBody);
    final shape = _shapeNames[prst ?? 'rect'] ?? SlideShape.rectangle;
    if (text.isEmpty && shape == SlideShape.rectangle) return null;
    final fillEl = xfrm?.parent?.findElements('a:solidFill').firstOrNull;
    final fillColor = _argb(
      fillEl?.findElements('a:srgbClr').firstOrNull?.getAttribute('val'),
    );
    final lineEl = node.findElements('p:spPr').firstOrNull?.findElements('a:ln').firstOrNull;
    final lineColor = _argb(
      lineEl?.findElements('a:solidFill').firstOrNull?.findElements('a:srgbClr').firstOrNull?.getAttribute('val'),
    );
    final lineWidthEmu = double.tryParse(lineEl?.getAttribute('w') ?? '');
    final rotationRaw = double.tryParse(xfrm?.getAttribute('rot') ?? '');
    final isPlaceholderTitle = node.findAllElements('p:ph').firstOrNull?.getAttribute('type') == 'title';
    if (text.isNotEmpty && shape == SlideShape.rectangle) {
      final element = SlideText()
        ..text = text
        ..style = style
        ..isTitle = isPlaceholderTitle;
      _applyFrame(element, off, ext, rotationRaw);
      element.id = id;
      return element;
    }
    final element = SlideShapeEl()
      ..shape = shape
      ..text = text
      ..style = style;
    if (fillColor != null) element.fill = fillColor;
    if (lineColor != null) element.line = lineColor;
    if (lineWidthEmu != null) element.lineWidth = lineWidthEmu / 12700;
    _applyFrame(element, off, ext, rotationRaw);
    element.id = id;
    return element;
  }
  static void _applyFrame(
    SlideElement element,
    XmlElement? off,
    XmlElement? ext,
    double? rotationRaw,
  ) {
    final x = double.tryParse(off?.getAttribute('x') ?? '');
    final y = double.tryParse(off?.getAttribute('y') ?? '');
    final cx = double.tryParse(ext?.getAttribute('cx') ?? '');
    final cy = double.tryParse(ext?.getAttribute('cy') ?? '');
    if (x != null) element.x = x / 12700;
    if (y != null) element.y = y / 12700;
    if (cx != null) element.w = cx / 12700;
    if (cy != null) element.h = cy / 12700;
    if (rotationRaw != null) element.rotation = rotationRaw / 60000;
  }
  static SlideTextStyle _readTextStyle(XmlElement? textBody) {
    if (textBody == null) return const SlideTextStyle();
    final runProps = textBody.findAllElements('a:rPr').firstOrNull;
    final defaultProps = textBody.findAllElements('a:defRPr').firstOrNull;
    final source = runProps ?? defaultProps;
    final size = double.tryParse(source?.getAttribute('sz') ?? '');
    final color = _argb(
      source?.findElements('a:solidFill').firstOrNull?.findElements('a:srgbClr').firstOrNull?.getAttribute('val'),
    );
    final align = textBody.findAllElements('a:pPr').firstOrNull?.getAttribute('algn');
    final anchor = textBody.getAttribute('anchor');
    return SlideTextStyle(
      fontFamily: source?.findElements('a:latin').firstOrNull?.getAttribute('typeface'),
      fontSize: size != null ? size / 100 : 18,
      bold: source?.getAttribute('b') == '1',
      italic: source?.getAttribute('i') == '1',
      underline: source?.getAttribute('u') != null,
      color: color ?? 0xFF2B2521,
      align: switch (align) {
        'ctr' => SlideTextAlign.center,
        'r' => SlideTextAlign.right,
        'just' => SlideTextAlign.justify,
        _ => SlideTextAlign.left,
      },
      valign: switch (anchor) {
        'ctr' => SlideVAlign.middle,
        'b' => SlideVAlign.bottom,
        _ => SlideVAlign.top,
      },
    );
  }
  static SlideElement? _readPicture(
    XmlElement node,
    Map<String, Uint8List> parts,
    Map<String, String> rels,
    String id,
  ) {
    final blip = node.findAllElements('a:blip').firstOrNull;
    final embed = blip?.getAttribute('embed', namespace: _nsR) ??
        blip?.getAttribute('r:embed') ??
        blip?.getAttribute('embed');
    if (embed == null) return null;
    final target = rels[embed];
    if (target == null) return null;
    final media = parts['ppt/${target.replaceFirst('../', '')}'];
    if (media == null) return null;
    final element = SlidePicture(bytes: media, mediaId: embed);
    final xfrm = node.findAllElements('a:xfrm').firstOrNull;
    _applyFrame(
      element,
      xfrm?.findElements('a:off').firstOrNull,
      xfrm?.findElements('a:ext').firstOrNull,
      double.tryParse(xfrm?.getAttribute('rot') ?? ''),
    );
    element.id = id;
    return element;
  }
  static SlideElement? _readGraphicFrame(XmlElement node, String id) {
    final table = node.findAllElements('a:tbl').firstOrNull;
    if (table == null) return null;
    final element = SlideTableEl();
    for (final row in table.findElements('a:tr')) {
      element.rows.add(
        row.findElements('a:tc').map((tc) => tc.innerText.trim()).toList(),
      );
    }
    final xfrm = node.findElements('p:xfrm').firstOrNull;
    final off = xfrm?.findElements('a:off').firstOrNull;
    final ext = xfrm?.findElements('a:ext').firstOrNull;
    _applyFrame(element, off, ext, null);
    element.id = id;
    return element;
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
  static int? _argb(String? value) {
    if (value == null || value.length < 6) return null;
    final parsed = int.tryParse(value.substring(0, 6), radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
  static List<int> _write(SlideDeck deck) {
    final archive = Archive();
    final mediaIndex = <String, String>{};
    for (final slide in deck.slides) {
      for (final element in slide.elements) {
        if (element is SlidePicture && !mediaIndex.containsKey(element.mediaId)) {
          final extension = _extensionFor(element.bytes);
          final name = 'image${mediaIndex.length + 1}$extension';
          mediaIndex[element.mediaId] = name;
          archive.addFile(
            ArchiveFile(
              'ppt/media/$name',
              element.bytes.length,
              element.bytes,
            ),
          );
        }
      }
    }
    archive.addFile(_bytes('[Content_Types].xml', _contentTypes(deck.slides.length, mediaIndex.values.toList())));
    archive.addFile(_bytes('_rels/.rels', _rootRels));
    archive.addFile(_bytes('docProps/core.xml', _coreXml(deck)));
    archive.addFile(_bytes('ppt/presentation.xml', _presentationXml(deck)));
    archive.addFile(_bytes('ppt/_rels/presentation.xml.rels', _presentationRels(deck.slides.length)));
    archive.addFile(_bytes('ppt/theme/theme1.xml', _themeXml));
    archive.addFile(_bytes('ppt/slideMasters/slideMaster1.xml', _masterXml));
    archive.addFile(_bytes('ppt/slideMasters/_rels/slideMaster1.xml.rels', _masterRels));
    archive.addFile(_bytes('ppt/slideLayouts/slideLayout1.xml', _layoutXml));
    archive.addFile(_bytes('ppt/slideLayouts/_rels/slideLayout1.xml.rels', _layoutRels));
    for (var i = 0; i < deck.slides.length; i++) {
      archive.addFile(
        _bytes('ppt/slides/slide${i + 1}.xml', _slideXml(deck.slides[i], i + 1)),
      );
      archive.addFile(
        _bytes(
          'ppt/slides/_rels/slide${i + 1}.xml.rels',
          _slideRels(i + 1, mediaIndex),
        ),
      );
    }
    return ZipEncoder().encode(archive);
  }
  static ArchiveFile _bytes(String name, String content) {
    final data = utf8.encode(content);
    return ArchiveFile(name, data.length, data);
  }
  static String _extensionFor(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return '.png';
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpeg';
    return '.png';
  }
  static String _contentTypes(int slideCount, List<String> media) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Default Extension="png" ContentType="image/png"/>')
      ..write('<Default Extension="jpeg" ContentType="image/jpeg"/>')
      ..write('<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>')
      ..write('<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>')
      ..write('<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>')
      ..write('<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>')
      ..write('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>');
    for (var i = 1; i <= slideCount; i++) {
      b.write(
        '<Override PartName="/ppt/slides/slide$i.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }
    b.write('</Types>');
    return b.toString();
  }
  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '</Relationships>';
  static String _coreXml(SlideDeck deck) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'cp:coreProperties',
      attributes: {
        'xmlns:cp': 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties',
        'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
      },
      nest: () {
        b.element('dc:title', nest: deck.title ?? 'Presentation');
        b.element('dc:creator', nest: deck.author ?? 'OpenFiles');
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _presentationXml(SlideDeck deck) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'p:presentation',
      attributes: {'xmlns:a': _nsA, 'xmlns:r': _nsR, 'xmlns:p': _nsP},
      nest: () {
        b.element('p:sldMasterIdLst', nest: () {
          b.element(
            'p:sldMasterId',
            attributes: {'id': '2147483648', 'r:id': 'rIdMaster'},
          );
        });
        b.element('p:sldIdLst', nest: () {
          for (var i = 0; i < deck.slides.length; i++) {
            b.element(
              'p:sldId',
              attributes: {'id': '${256 + i}', 'r:id': 'rIdSlide$i'},
            );
          }
        });
        b.element('p:sldSz', attributes: {
          'cx': '${(deck.widthPt * 12700).round()}',
          'cy': '${(deck.heightPt * 12700).round()}',
        });
        b.element('p:notesSz', attributes: {'cx': '6858000', 'cy': '9144000'});
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _presentationRels(int slideCount) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
      ..write('<Relationship Id="rIdMaster" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    for (var i = 0; i < slideCount; i++) {
      b.write(
        '<Relationship Id="rIdSlide$i" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
        'Target="slides/slide${i + 1}.xml"/>',
      );
    }
    b.write('<Relationship Id="rIdTheme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>');
    b.write('</Relationships>');
    return b.toString();
  }
  static const String _masterRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rIdLayout1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
      '<Relationship Id="rIdTheme1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>'
      '</Relationships>';
  static const String _layoutRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>'
      '</Relationships>';
  static String get _masterXml {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'p:sldMaster',
      attributes: {'xmlns:a': _nsA, 'xmlns:r': _nsR, 'xmlns:p': _nsP},
      nest: () {
        b.element('p:cSld', nest: () {
          b.element('p:spTree', nest: () {
            b.element('p:nvGrpSpPr', nest: () {
              b.element('p:cNvPr', attributes: {'id': '1', 'name': ''});
              b.element('p:cNvGrpSpPr');
              b.element('p:nvPr');
            });
            b.element('p:grpSpPr');
          });
        });
        b.element('p:clrMap', attributes: {
          'bg1': 'lt1',
          'tx1': 'dk1',
          'bg2': 'lt2',
          'tx2': 'dk2',
          'accent1': 'accent1',
          'accent2': 'accent2',
          'accent3': 'accent3',
          'accent4': 'accent4',
          'accent5': 'accent5',
          'accent6': 'accent6',
          'hlink': 'hlink',
          'folHlink': 'folHlink',
        });
        b.element('p:sldLayoutIdLst', nest: () {
          b.element('p:sldLayoutId', attributes: {'id': '2147483649', 'r:id': 'rIdLayout1'});
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String get _layoutXml {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'p:sldLayout',
      attributes: {
        'xmlns:a': _nsA,
        'xmlns:r': _nsR,
        'xmlns:p': _nsP,
        'type': 'blank',
        'preserve': '1',
      },
      nest: () {
        b.element('p:cSld', attributes: {'name': 'Blank'}, nest: () {
          b.element('p:spTree', nest: () {
            b.element('p:nvGrpSpPr', nest: () {
              b.element('p:cNvPr', attributes: {'id': '1', 'name': ''});
              b.element('p:cNvGrpSpPr');
              b.element('p:nvPr');
            });
            b.element('p:grpSpPr');
          });
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String get _themeXml {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'a:theme',
      attributes: {'xmlns:a': _nsA, 'name': 'OpenFiles'},
      nest: () {
        b.element('a:themeElements', nest: () {
          b.element('a:clrScheme', attributes: {'name': 'Warm'}, nest: () {
            _colorEntry(b, 'dk1', '000000');
            _colorEntry(b, 'lt1', 'FFFFFF');
            _colorEntry(b, 'dk2', '3B332C');
            _colorEntry(b, 'lt2', 'FAF5EF');
            for (final name in ['accent1', 'accent2', 'accent3', 'accent4', 'accent5', 'accent6']) {
              _colorEntry(b, name, 'C08163');
            }
            _colorEntry(b, 'hlink', '6E8CA0');
            _colorEntry(b, 'folHlink', '7F9079');
          });
          b.element('a:fontScheme', attributes: {'name': 'Warm'}, nest: () {
            b.element('a:majorFont', nest: () {
              b.element('a:latin', attributes: {'typeface': 'Calibri Light'});
              b.element('a:ea', attributes: {'typeface': ''});
              b.element('a:cs', attributes: {'typeface': ''});
            });
            b.element('a:minorFont', nest: () {
              b.element('a:latin', attributes: {'typeface': 'Calibri'});
              b.element('a:ea', attributes: {'typeface': ''});
              b.element('a:cs', attributes: {'typeface': ''});
            });
          });
          b.element('a:fmtScheme', attributes: {'name': 'Warm'}, nest: () {
            b.element('a:fillStyleLst', nest: () {
              _fillStyle(b, 'solidFill');
              _fillStyle(b, 'gradFill');
              _fillStyle(b, 'solidFill');
            });
            b.element('a:lnStyleLst', nest: () {
              for (var i = 0; i < 3; i++) {
                b.element('a:ln', attributes: {'w': '${6350 * (i + 1)}', 'cap': 'flat'}, nest: () {
                  b.element('a:solidFill', nest: () {
                    b.element('a:schemeClr', attributes: {'val': 'phClr'});
                  });
                });
              }
            });
            b.element('a:effectStyleLst', nest: () {
              for (var i = 0; i < 3; i++) {
                b.element('a:effectStyle', nest: () {
                  b.element('a:effectLst');
                });
              }
            });
            b.element('a:bgFillStyleLst', nest: () {
              _fillStyle(b, 'solidFill');
              _fillStyle(b, 'solidFill');
              _fillStyle(b, 'solidFill');
            });
          });
        });
      },
    );
    return b.buildDocument().toXmlString();
  }
  static void _colorEntry(XmlBuilder b, String name, String hex) {
    b.element(name, nest: () {
      b.element('a:srgbClr', attributes: {'val': hex});
    });
  }
  static void _fillStyle(XmlBuilder b, String kind) {
    b.element(kind, nest: () {
      b.element('a:schemeClr', attributes: {'val': 'phClr'});
    });
  }
  static String _slideXml(Slide slide, int index) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    b.element(
      'p:sld',
      attributes: {
        'xmlns:a': _nsA,
        'xmlns:r': _nsR,
        'xmlns:p': _nsP,
        'xmlns:mc': 'http://schemas.openxmlformats.org/markup-compatibility/2006',
        'mc:Ignorable': 'p14',
        'xmlns:p14': 'http://schemas.microsoft.com/office/powerpoint/2010/main',
      },
      nest: () {
        b.element('p:cSld', nest: () {
          if (slide.background != null) {
            b.element('p:bg', nest: () {
              b.element('p:bgPr', nest: () {
                b.element('a:solidFill', nest: () {
                  b.element('a:srgbClr', attributes: {'val': _hex(slide.background!)});
                });
                b.element('a:effectLst');
              });
            });
          }
          b.element('p:spTree', nest: () {
            b.element('p:nvGrpSpPr', nest: () {
              b.element('p:cNvPr', attributes: {'id': '1', 'name': ''});
              b.element('p:cNvGrpSpPr');
              b.element('p:nvPr');
            });
            b.element('p:grpSpPr');
            var id = 2;
            for (final element in slide.elements) {
              switch (element) {
                case final SlideText value:
                  _writeText(b, value, id++);
                case final SlideShapeEl value:
                  _writeShape(b, value, id++);
                case final SlidePicture value:
                  _writePicture(b, value, id++);
                case final SlideTableEl value:
                  _writeTable(b, value, id++);
              }
            }
          });
        });
        if (slide.transition != SlideTransition.none) {
          b.element('p:transition', attributes: {'spd': _speed(slide.transitionDuration)}, nest: () {
            b.element(_transitionTag(slide.transition));
          });
        }
        b.element('p:clrMapOvr', nest: () => b.element('a:overrideClrMapping'));
      },
    );
    return b.buildDocument().toXmlString();
  }
  static String _speed(double seconds) =>
      seconds >= 1.2 ? 'slow' : (seconds <= 0.5 ? 'fast' : 'med');
  static String _transitionTag(SlideTransition transition) => switch (transition) {
        SlideTransition.none => 'p:fade',
        _ => 'p:${transition.name == 'switchMode' ? 'switch' : transition.name == 'unCover' ? 'uncover' : transition.name == 'randomBars' ? 'randomBar' : transition.name == 'flyThrough' ? 'flythrough' : transition.name}',
      };
  static String _slideRels(int index, Map<String, String> mediaIndex) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
      ..write(
        '<Relationship Id="rIdLayout$index" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" '
        'Target="../slideLayouts/slideLayout1.xml"/>',
      );
    for (final entry in mediaIndex.entries) {
      b.write(
        '<Relationship Id="${entry.key}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="../media/${entry.value}"/>',
      );
    }
    b.write('</Relationships>');
    return b.toString();
  }
  static void _xfrm(
    XmlBuilder b,
    SlideElement element, {
    required bool rotate,
  }) {
    b.element('a:xfrm', attributes: {
      if (rotate && element.rotation != 0) 'rot': '${(element.rotation * 60000).round()}',
    }, nest: () {
      b.element('a:off', attributes: {
        'x': '${(element.x * 12700).round()}',
        'y': '${(element.y * 12700).round()}',
      });
      b.element('a:ext', attributes: {
        'cx': '${(element.w * 12700).round()}',
        'cy': '${(element.h * 12700).round()}',
      });
    });
  }
  static void _writeText(XmlBuilder b, SlideText element, int id) {
    b.element('p:sp', nest: () {
      b.element('p:nvSpPr', nest: () {
        b.element('p:cNvPr', attributes: {'id': '$id', 'name': 'TextBox $id'});
        b.element('p:cNvSpPr', attributes: {'txBox': '1'});
        b.element('p:nvPr');
      });
      b.element('p:spPr', nest: () {
        _xfrm(b, element, rotate: true);
        b.element('a:prstGeom', attributes: {'prst': 'rect'}, nest: () {
          b.element('a:avLst');
        });
        b.element('a:noFill');
      });
      b.element('p:txBody', nest: () {
        b.element('a:bodyPr', attributes: {
          'wrap': 'square',
          'anchor': switch (element.style.valign) {
            SlideVAlign.middle => 'ctr',
            SlideVAlign.bottom => 'b',
            _ => 't',
          },
        });
        b.element('a:lstStyle');
        for (final line in element.text.split('\n')) {
          b.element('a:p', nest: () {
            b.element('a:pPr', attributes: {
              'algn': switch (element.style.align) {
                SlideTextAlign.center => 'ctr',
                SlideTextAlign.right => 'r',
                SlideTextAlign.justify => 'just',
                _ => 'l',
              },
            });
            b.element('a:r', nest: () {
              b.element('a:rPr', attributes: {
                'lang': 'en-US',
                'sz': '${(element.style.fontSize * 100).round()}',
                'b': element.style.bold ? '1' : '0',
                'i': element.style.italic ? '1' : '0',
                'u': element.style.underline ? 'sng' : 'none',
              }, nest: () {
                b.element('a:solidFill', nest: () {
                  b.element('a:srgbClr', attributes: {'val': _hex(element.style.color)});
                });
                if (element.style.fontFamily != null) {
                  b.element('a:latin', attributes: {'typeface': element.style.fontFamily!});
                }
              });
              b.element('a:t', nest: line);
            });
          });
        }
      });
    });
  }
  static void _writeShape(XmlBuilder b, SlideShapeEl element, int id) {
    b.element('p:sp', nest: () {
      b.element('p:nvSpPr', nest: () {
        b.element('p:cNvPr', attributes: {'id': '$id', 'name': 'Shape $id'});
        b.element('p:cNvSpPr');
        b.element('p:nvPr');
      });
      b.element('p:spPr', nest: () {
        _xfrm(b, element, rotate: true);
        b.element('a:prstGeom', attributes: {'prst': _shapePrst[element.shape]!}, nest: () {
          b.element('a:avLst');
        });
        b.element('a:solidFill', nest: () {
          b.element('a:srgbClr', attributes: {'val': _hex(element.fill)});
        });
        if (element.lineWidth > 0) {
          b.element('a:ln', attributes: {'w': '${(element.lineWidth * 12700).round()}'}, nest: () {
            b.element('a:solidFill', nest: () {
              b.element('a:srgbClr', attributes: {'val': _hex(element.line)});
            });
          });
        }
      });
      b.element('p:txBody', nest: () {
        b.element('a:bodyPr', attributes: {
          'anchor': switch (element.style.valign) {
            SlideVAlign.middle => 'ctr',
            SlideVAlign.bottom => 'b',
            _ => 't',
          },
        });
        b.element('a:lstStyle');
        b.element('a:p', nest: () {
          b.element('a:r', nest: () {
            b.element('a:rPr', attributes: {
              'lang': 'en-US',
              'sz': '${(element.style.fontSize * 100).round()}',
              'b': element.style.bold ? '1' : '0',
            }, nest: () {
              b.element('a:solidFill', nest: () {
                b.element('a:srgbClr', attributes: {'val': _hex(element.style.color)});
              });
            });
            b.element('a:t', nest: element.text);
          });
        });
      });
    });
  }
  static void _writePicture(XmlBuilder b, SlidePicture element, int id) {
    b.element('p:pic', nest: () {
      b.element('p:nvPicPr', nest: () {
        b.element('p:cNvPr', attributes: {'id': '$id', 'name': 'Picture $id'});
        b.element('p:cNvPicPr');
        b.element('p:nvPr');
      });
      b.element('p:blipFill', nest: () {
        b.element('a:blip', attributes: {'r:embed': element.mediaId});
        b.element('a:stretch', nest: () => b.element('a:fillRect'));
      });
      b.element('p:spPr', nest: () {
        _xfrm(b, element, rotate: true);
        b.element('a:prstGeom', attributes: {'prst': 'rect'}, nest: () {
          b.element('a:avLst');
        });
      });
    });
  }
  static void _writeTable(XmlBuilder b, SlideTableEl element, int id) {
    final columns = element.rows.isEmpty
        ? 1
        : element.rows.fold<int>(0, (acc, r) => r.length > acc ? r.length : acc);
    b.element('p:graphicFrame', nest: () {
      b.element('p:nvGraphicFramePr', nest: () {
        b.element('p:cNvPr', attributes: {'id': '$id', 'name': 'Table $id'});
        b.element('p:cNvGraphicFramePr');
        b.element('p:nvPr');
      });
      b.element('p:xfrm', nest: () {
        b.element('a:off', attributes: {
          'x': '${(element.x * 12700).round()}',
          'y': '${(element.y * 12700).round()}',
        });
        b.element('a:ext', attributes: {
          'cx': '${(element.w * 12700).round()}',
          'cy': '${(element.h * 12700).round()}',
        });
      });
      b.element('a:graphic', nest: () {
        b.element('a:graphicData', attributes: {'uri': _nsTable}, nest: () {
          b.element('a:tbl', nest: () {
            for (final row in element.rows) {
              b.element('a:tr', attributes: {'h': '370840'}, nest: () {
                for (var c = 0; c < columns; c++) {
                  b.element('a:tc', nest: () {
                    b.element('a:txBody', nest: () {
                      b.element('a:bodyPr');
                      b.element('a:lstStyle');
                      b.element('a:p', nest: () {
                        b.element('a:r', nest: () {
                          b.element('a:rPr', attributes: {'lang': 'en-US', 'sz': '1200'});
                          b.element('a:t', nest: c < row.length ? row[c] : '');
                        });
                      });
                    });
                    b.element('a:tcPr');
                  });
                }
              });
            }
          });
        });
      });
    });
  }
  static String _hex(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  static const _nsA =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _nsP =
      'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const _nsTable =
      'http://schemas.openxmlformats.org/drawingml/2006/table';
}
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
