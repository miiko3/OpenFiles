import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide SlideTransition;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/pdf_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/fs_node.dart';
import '../../data/services/saf_service.dart';
import '../../widgets/common.dart';
import '../browser/viewers/slides_painter.dart';
import 'pptx_codec.dart';
import 'slides_presenter.dart';
class SlidesEditor extends StatefulWidget {
  const SlidesEditor({super.key, required this.node});
  final FsNode node;
  @override
  State<SlidesEditor> createState() => _SlidesEditorState();
}
class _SlidesEditorState extends State<SlidesEditor> {
  final _saf = SafService.instance;
  final List<SlideDeck> _undo = [];
  final List<SlideDeck> _redo = [];
  late SlideDeck _deck;
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  int _index = 0;
  String? _selectedId;
  bool _showNotes = false;
  double _zoom = 1.0;
  Size _viewport = const Size(360, 240);
  final Map<String, ui.Image> _images = {};
  final Map<String, TextEditingController> _notesControllers = {};
  Slide get _slide => _deck.slides[_index.clamp(0, _deck.slides.length - 1)];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
      final deck = await PptxCodec.load(bytes);
      if (deck.slides.isEmpty) deck.slides.add(_blankSlide());
      _deck = deck;
      await _decodeImages();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  Future<void> _decodeImages() async {
    for (final slide in _deck.slides) {
      for (final element in slide.elements) {
        if (element is SlidePicture && !_images.containsKey(element.id)) {
          try {
            final codec = await ui.instantiateImageCodec(element.bytes);
            final frame = await codec.getNextFrame();
            _images[element.id] = frame.image;
          } catch (_) {}
        }
      }
    }
  }
  static Slide _blankSlide() {
    final title = SlideText()
      ..text = 'New slide'
      ..isTitle = true
      ..style = const SlideTextStyle(fontSize: 34, bold: true);
    title
      ..id = 't1'
      ..x = 60
      ..y = 70
      ..w = 840
      ..h = 80;
    final body = SlideText()
      ..text = 'Tap to add text'
      ..style = const SlideTextStyle(fontSize: 18, color: 0xFF8C8075);
    body
      ..id = 't2'
      ..x = 60
      ..y = 170
      ..w = 840
      ..h = 260;
    return Slide()..elements.addAll([title, body]);
  }
  void _pushUndo() {
    _undo.add(_cloneDeck());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }
  SlideDeck _cloneDeck() {
    final copy = SlideDeck(
      slides: _deck.slides.map((s) => s.clone()).toList(),
      widthPt: _deck.widthPt,
      heightPt: _deck.heightPt,
    )
      ..title = _deck.title
      ..author = _deck.author;
    return copy;
  }
  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_cloneDeck());
    setState(() => _deck = _undo.removeLast());
  }
  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_cloneDeck());
    setState(() => _deck = _redo.removeLast());
  }
  void _addSlide() {
    _pushUndo();
    setState(() {
      _deck.slides.insert(_index + 1, _blankSlide());
      _index++;
      _dirty = true;
    });
  }
  void _duplicateSlide() {
    _pushUndo();
    setState(() {
      _deck.slides.insert(_index + 1, _slide.clone());
      _index++;
      _dirty = true;
    });
  }
  void _deleteSlide() {
    if (_deck.slides.length <= 1) return;
    _pushUndo();
    setState(() {
      _deck.slides.removeAt(_index);
      _index = (_index - 1).clamp(0, _deck.slides.length - 1);
      _dirty = true;
    });
  }
  void _moveSlide(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= _deck.slides.length) return;
    _pushUndo();
    setState(() {
      final slide = _deck.slides.removeAt(_index);
      _deck.slides.insert(target, slide);
      _index = target;
      _dirty = true;
    });
  }
  SlideElement? get _selected {
    if (_selectedId == null) return null;
    for (final element in _slide.elements) {
      if (element.id == _selectedId) return element;
    }
    return null;
  }
  SlideElement? _hitTest(Offset local, Size size) {
    final scale = size.width / _deck.widthPt;
    for (var i = _slide.elements.length - 1; i >= 0; i--) {
      final element = _slide.elements[i];
      final rect = Rect.fromLTWH(
        element.x * scale,
        element.y * scale,
        element.w * scale,
        element.h * scale,
      );
      if (rect.contains(local)) return element;
    }
    return null;
  }
  void _addText() {
    _pushUndo();
    final element = SlideText()
      ..text = 'Text'
      ..style = const SlideTextStyle(fontSize: 20);
    element
      ..id = 't${DateTime.now().microsecondsSinceEpoch}'
      ..x = 80
      ..y = 80
      ..w = 400
      ..h = 60;
    setState(() {
      _slide.elements.add(element);
      _selectedId = element.id;
      _dirty = true;
    });
  }
  void _addShape(SlideShape shape) {
    _pushUndo();
    final element = SlideShapeEl()
      ..shape = shape
      ..fill = 0xFFC08163
      ..text = switch (shape) {
        SlideShape.callout => 'Callout',
        SlideShape.rightArrow => '',
        _ => '',
      }
      ..style = const SlideTextStyle(fontSize: 16, color: 0xFFFFFFFF);
    element
      ..id = 's${DateTime.now().microsecondsSinceEpoch}'
      ..x = 120
      ..y = 140
      ..w = 260
      ..h = 120;
    setState(() {
      _slide.elements.add(element);
      _selectedId = element.id;
      _dirty = true;
    });
  }
  void _addTable() {
    _pushUndo();
    final element = SlideTableEl()
      ..rows = [
        ['Header 1', 'Header 2'],
        for (var i = 0; i < 3; i++) ['Cell', 'Cell'],
      ];
    element
      ..id = 'g${DateTime.now().microsecondsSinceEpoch}'
      ..x = 90
      ..y = 130
      ..w = 780
      ..h = 240;
    setState(() {
      _slide.elements.add(element);
      _selectedId = element.id;
      _dirty = true;
    });
  }
  void _deleteSelected() {
    final element = _selected;
    if (element == null) return;
    _pushUndo();
    setState(() {
      _slide.elements.remove(element);
      _selectedId = null;
      _dirty = true;
    });
  }
  void _reorder(int delta) {
    final element = _selected;
    if (element == null) return;
    final position = _slide.elements.indexOf(element);
    final target = position + delta;
    if (target < 0 || target >= _slide.elements.length) return;
    _pushUndo();
    setState(() {
      _slide.elements.removeAt(position);
      _slide.elements.insert(target, element);
      _dirty = true;
    });
  }
  void _updateSelected(void Function(SlideElement element) transform) {
    final element = _selected;
    if (element == null) return;
    _pushUndo();
    setState(() {
      transform(element);
      _dirty = true;
    });
  }
  Future<void> _save() async {
    try {
      final bytes = await PptxCodec.save(_deck);
      await _saf.writeBytes(widget.node, bytes);
      if (!mounted) return;
      setState(() => _dirty = false);
      _toast('Saved ${widget.node.name}');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _exportPdf() async {
    try {
      final fonts = await PdfFonts.load();
      final doc = pw.Document(theme: fonts.theme());
      for (final slide in _deck.slides) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              _deck.widthPt * 0.75,
              _deck.heightPt * 0.75,
              marginAll: 0,
            ),
            build: (_) => pw.Stack(
              children: [
                if (slide.background != null)
                  pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Container(color: PdfColor.fromInt(slide.background!)),
                  ),
                for (final element in slide.elements)
                  _pdfElement(element),
              ],
            ),
          ),
        );
      }
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${widget.node.name}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    }
  }
  pw.Widget _pdfElement(SlideElement element) {
    pw.Widget content;
    switch (element) {
      case final SlideText value:
        content = pw.Text(
          value.text,
          style: pw.TextStyle(
            fontSize: value.style.fontSize * 0.75,
            fontWeight: value.style.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: value.style.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            color: PdfColor.fromInt(value.style.color),
          ),
          textAlign: switch (value.style.align) {
            SlideTextAlign.center => pw.TextAlign.center,
            SlideTextAlign.right => pw.TextAlign.right,
            SlideTextAlign.justify => pw.TextAlign.justify,
            _ => pw.TextAlign.left,
          },
        );
      case final SlideShapeEl value:
        content = pw.Container(
          color: PdfColor.fromInt(value.fill),
          alignment: pw.Alignment.center,
          child: value.text.isEmpty
              ? pw.SizedBox()
              : pw.Text(
                  value.text,
                  style: pw.TextStyle(
                    fontSize: value.style.fontSize * 0.75,
                    color: PdfColor.fromInt(value.style.color),
                  ),
                ),
        );
      case final SlidePicture value:
        try {
          content = pw.Image(
            pw.MemoryImage(value.bytes),
            fit: pw.BoxFit.fill,
          );
        } catch (_) {
          content = pw.SizedBox();
        }
      case final SlideTableEl value:
        content = pw.Table(
          children: [
            for (final row in value.rows)
              pw.TableRow(
                children: [
                  for (final cell in row)
                    pw.Expanded(child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9))),
                ],
              ),
          ],
        );
    }
    return pw.SizedBox(
      width: element.w * 0.75,
      height: element.h * 0.75,
      child: pw.Padding(
        padding: pw.EdgeInsets.only(
          left: element.x * 0.75,
          top: element.y * 0.75,
        ),
        child: content,
      ),
    );
  }
  Future<void> _present() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SlidesPresenter(deck: _deck, startIndex: _index),
      ),
    );
  }
  Future<void> _editText(SlideElement element) async {
    final value = element is SlideText
        ? element.text
        : element is SlideShapeEl
            ? element.text
            : '';
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 8,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    _pushUndo();
    setState(() {
      if (element is SlideText) element.text = result;
      if (element is SlideShapeEl) element.text = result;
      _dirty = true;
    });
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) return const LoadingOverlay(visible: true, message: 'Opening deck');
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    return Column(
      children: [
        _topBar(c),
        Expanded(
          child: Row(
            children: [
              _thumbnailPane(c),
              VerticalDivider(width: 1, color: c.border),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _canvasPane(c)),
                    if (_showNotes) _notesPane(c),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: c.border),
              _propertyPane(c),
            ],
          ),
        ),
        _toolbar(c),
        StatusBar(
          items: [
            Text('Slide ${_index + 1} / ${_deck.slides.length}'),
            const Spacer(),
            if (_selected != null) Text(_selectedId ?? ''),
            const Spacer(),
            Text(_slide.transition == SlideTransition.none
                ? 'no transition'
                : _slide.transition.name),
          ],
        ),
      ],
    );
  }
  Widget _topBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.sm,
      ),
      color: c.bg,
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 34,
            iconSize: 16,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpace.sm),
          const Icon(Icons.slideshow_outlined, size: 18),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              widget.node.name,
              style: context.t.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_dirty)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
          RoundIconButton(
            icon: Icons.play_circle_outline_rounded,
            size: 34,
            iconSize: 19,
            tooltip: 'Present',
            onPressed: _present,
          ),
          RoundIconButton(
            icon: Icons.picture_as_pdf_outlined,
            size: 34,
            iconSize: 17,
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
          RoundIconButton(
            icon: Icons.save_outlined,
            size: 34,
            iconSize: 17,
            tooltip: 'Save',
            onPressed: _dirty ? _save : null,
          ),
          RoundIconButton(
            icon: Icons.more_vert_rounded,
            size: 34,
            iconSize: 17,
            tooltip: 'More',
            onPressed: () => _showMenu(c),
          ),
        ],
      ),
    );
  }
  Future<void> _showMenu(AppColors c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notes_rounded),
              title: Text(_showNotes ? 'Hide notes' : 'Show notes'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _showNotes = !_showNotes);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_16_9_rounded),
              title: const Text('Slide size 16:9'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pushUndo();
                setState(() {
                  _deck.widthPt = 960;
                  _deck.heightPt = 540;
                  _dirty = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_landscape_rounded),
              title: const Text('Slide size 4:3'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pushUndo();
                setState(() {
                  _deck.widthPt = 720;
                  _deck.heightPt = 540;
                  _dirty = true;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Clear all slides'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pushUndo();
                setState(() {
                  _deck.slides
                    ..clear()
                    ..add(_blankSlide());
                  _index = 0;
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  Widget _thumbnailPane(AppColors c) {
    return Container(
      width: 118,
      color: c.surfaceAlt,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpace.sm),
        itemCount: _deck.slides.length + 1,
        itemBuilder: (context, i) {
          if (i == _deck.slides.length) {
            return GestureDetector(
              onTap: _addSlide,
              child: Container(
                height: 66,
                margin: const EdgeInsets.only(bottom: AppSpace.sm),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: AppRadius.md,
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.add_rounded, color: c.textFaint),
              ),
            );
          }
          final active = i == _index;
          return GestureDetector(
            onTap: () => setState(() {
              _index = i;
              _selectedId = null;
            }),
            onLongPress: () => _slideMenu(i),
            child: Container(
              height: 66,
              margin: const EdgeInsets.only(bottom: AppSpace.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.sm,
                border: Border.all(
                  color: active ? c.primary : c.border,
                  width: active ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, box) => CustomPaint(
                        painter: SlidePainter(
                          slide: _deck.slides[i],
                          deckWidth: _deck.widthPt,
                          deckHeight: _deck.heightPt,
                          images: _images,
                          scaleOverride: box.biggest.width / _deck.widthPt,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 3,
                    bottom: 2,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontSize: 9, color: const Color(0xFF8C8075)),
                    ),
                  ),
                  if (_deck.slides[i].transition != SlideTransition.none)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 10,
                        color: c.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Future<void> _slideMenu(int i) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Дублировать'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _index = i;
                  _duplicateSlide();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded),
              title: const Text('Выше'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _index = i;
                  _moveSlide(-1);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded),
              title: const Text('Ниже'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _index = i;
                  _moveSlide(1);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _index = i;
                  _deleteSlide();
                });
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
  Widget _canvasPane(AppColors c) {
    return LayoutBuilder(
      builder: (context, box) {
        final available = Size(box.maxWidth - 32, box.maxHeight - 32);
        final ratio = _deck.widthPt / _deck.heightPt;
        var width = available.width;
        var height = width / ratio;
        if (height > available.height) {
          height = available.height;
          width = height * ratio;
        }
        width *= _zoom;
        height *= _zoom;
        _viewport = Size(width, height);
        return Container(
          color: c.canvas,
          child: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTapUp: (details) {
                    final local = details.localPosition;
                    final hit = _hitTest(local, _viewport);
                    setState(() => _selectedId = hit?.id);
                    if (hit is SlideText || hit is SlideShapeEl) {
                      _editText(hit!);
                    }
                  },
                  onPanUpdate: (details) {
                    final hit = _hitTest(details.localPosition, _viewport);
                    if (hit != null && hit.id == _selectedId) return;
                    setState(() => _selectedId = hit?.id);
                  },
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.sm,
                      boxShadow: [
                        BoxShadow(
                          color: c.shadow,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      painter: SlidePainter(
                        slide: _slide,
                        deckWidth: _deck.widthPt,
                        deckHeight: _deck.heightPt,
                        images: _images,
                        selectedId: _selectedId,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpace.sm,
                bottom: AppSpace.sm,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.remove_rounded,
                        size: 28,
                        iconSize: 15,
                        onPressed: () => setState(
                          () => _zoom = (_zoom - 0.15).clamp(0.4, 3.0),
                        ),
                      ),
                      Text('${(_zoom * 100).round()}%', style: context.t.labelSmall),
                      RoundIconButton(
                        icon: Icons.add_rounded,
                        size: 28,
                        iconSize: 15,
                        onPressed: () => setState(
                          () => _zoom = (_zoom + 0.15).clamp(0.4, 3.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _notesPane(AppColors c) {
    final key = 'notes$_index';
    final controller = _notesControllers.putIfAbsent(
      key,
      () => TextEditingController(text: _slide.notes),
    );
    return Container(
      height: 96,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Заметки докладчика', style: context.t.labelSmall),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: 13, color: c.text),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                _slide.notes = value;
                _dirty = true;
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _propertyPane(AppColors c) {
    final element = _selected;
    return Container(
      width: 176,
      color: c.surface,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PROPERTIES', style: context.t.labelSmall?.copyWith(color: c.primary)),
            const SizedBox(height: AppSpace.sm),
            if (element == null)
              Text('Выберите объект', style: context.t.bodySmall)
            else ...[
              _field('X', element.x, (v) => _updateSelected((e) => e.x = v)),
              _field('Y', element.y, (v) => _updateSelected((e) => e.y = v)),
              _field('W', element.w, (v) => _updateSelected((e) => e.w = v)),
              _field('H', element.h, (v) => _updateSelected((e) => e.h = v)),
              _field(
                'Rotation',
                element.rotation,
                (v) => _updateSelected((e) => e.rotation = v),
              ),
              const SizedBox(height: AppSpace.sm),
              if (element is SlideShapeEl || element is SlideText) ...[
                Text('Fill', style: context.t.labelSmall),
                const SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in _palette(c))
                      GestureDetector(
                        onTap: () => _updateSelected((e) {
                          if (e is SlideShapeEl) e.fill = value;
                          if (e is SlideText) {
                            e.style = e.style.copyWith(color: value);
                          }
                        }),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(value),
                            borderRadius: AppRadius.sm,
                            border: Border.all(color: c.border),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                if (element is SlideText || element is SlideShapeEl) ...[
                  _slider(
                    'Font size',
                    element is SlideText ? element.style.fontSize : (element as SlideShapeEl).style.fontSize,
                    8,
                    72,
                    (v) => _updateSelected((e) {
                      if (e is SlideText) e.style = e.style.copyWith(fontSize: v);
                      if (e is SlideShapeEl) e.style = e.style.copyWith(fontSize: v);
                    }),
                  ),
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.format_bold_rounded,
                        size: 30,
                        iconSize: 16,
                        active: element is SlideText && element.style.bold,
                        onPressed: () => _updateSelected((e) {
                          if (e is SlideText) {
                            e.style = e.style.copyWith(bold: !e.style.bold);
                          }
                          if (e is SlideShapeEl) {
                            e.style = e.style.copyWith(bold: !e.style.bold);
                          }
                        }),
                      ),
                      RoundIconButton(
                        icon: Icons.format_align_left_rounded,
                        size: 30,
                        iconSize: 16,
                        active: element is SlideText && element.style.align == SlideTextAlign.left,
                        onPressed: () => _updateSelected((e) {
                          if (e is SlideText) {
                            e.style = e.style.copyWith(align: SlideTextAlign.left);
                          }
                        }),
                      ),
                      RoundIconButton(
                        icon: Icons.format_align_center_rounded,
                        size: 30,
                        iconSize: 16,
                        active: element is SlideText && element.style.align == SlideTextAlign.center,
                        onPressed: () => _updateSelected((e) {
                          if (e is SlideText) {
                            e.style = e.style.copyWith(align: SlideTextAlign.center);
                          }
                        }),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: AppSpace.md),
              RoundIconButton(
                icon: Icons.delete_outline_rounded,
                size: 32,
                iconSize: 17,
                danger: true,
                tooltip: 'Удалить',
                onPressed: _deleteSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
  List<int> _palette(AppColors c) => [
        c.text.toARGB32(),
        0xFFC08163,
        0xFF7F9079,
        0xFFB08D57,
        0xFF6E8CA0,
        0xFFB5645A,
        0xFF8A8078,
        0xFFFFFFFF,
      ];
  Widget _field(String label, double value, ValueChanged<double> onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: context.t.bodySmall)),
          Expanded(
            child: TextFormField(
              initialValue: value.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: TextStyle(fontSize: 12, color: context.c.text),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onFieldSubmitted: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null) onChange(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.t.labelSmall),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChange,
        ),
      ],
    );
  }
  Widget _toolbar(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            RoundIconButton(
              icon: Icons.undo_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Undo',
              onPressed: _undo.isEmpty ? null : _undoEdit,
            ),
            RoundIconButton(
              icon: Icons.redo_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Redo',
              onPressed: _redo.isEmpty ? null : _redoEdit,
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.title_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Text box',
              onPressed: _addText,
            ),
            RoundIconButton(
              icon: Icons.category_outlined,
              size: 34,
              iconSize: 17,
              tooltip: 'Shape',
              onPressed: _shapePicker,
            ),
            RoundIconButton(
              icon: Icons.table_chart_outlined,
              size: 34,
              iconSize: 17,
              tooltip: 'Table',
              onPressed: _addTable,
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.flip_to_front_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Bring forward',
              onPressed: () => _reorder(1),
            ),
            RoundIconButton(
              icon: Icons.flip_to_back_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Send backward',
              onPressed: () => _reorder(-1),
            ),
            RoundIconButton(
              icon: Icons.delete_outline_rounded,
              size: 34,
              iconSize: 17,
              danger: true,
              tooltip: 'Удалить',
              onPressed: _deleteSelected,
            ),
            _sep(c),
            RoundIconButton(
              icon: Icons.content_copy_rounded,
              size: 34,
              iconSize: 17,
              tooltip: 'Duplicate slide',
              onPressed: _duplicateSlide,
            ),
            RoundIconButton(
              icon: Icons.delete_sweep_outlined,
              size: 34,
              iconSize: 17,
              tooltip: 'Delete slide',
              onPressed: _deleteSlide,
            ),
            _sep(c),
            _transitionPicker(c),
          ],
        ),
      ),
    );
  }
  Future<void> _shapePicker() async {
    final picked = await showRoundedSheet<SlideShape>(
      context,
      title: 'Вставить фигуру',
      child: Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          for (final shape in SlideShape.values)
            PillButton(
              label: shape.name,
              dense: true,
              onPressed: () => Navigator.of(context).pop(shape),
            ),
        ],
      ),
    );
    if (picked != null) _addShape(picked);
  }
  Widget _transitionPicker(AppColors c) {
    return PopupMenuButton<SlideTransition>(
      tooltip: 'Transition',
      initialValue: _slide.transition,
      onSelected: (value) {
        _pushUndo();
        setState(() {
          _slide.transition = value;
          _dirty = true;
        });
      },
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (context) => [
        for (final value in SlideTransition.values)
          PopupMenuItem(value: value, child: Text(value.name)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _slide.transition == SlideTransition.none
              ? c.surfaceAlt
              : c.primarySoft,
          borderRadius: AppRadius.sm,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: _slide.transition == SlideTransition.none
                  ? c.textDim
                  : c.primary,
            ),
            const SizedBox(width: 4),
            Text(
              _slide.transition == SlideTransition.none
                  ? 'None'
                  : _slide.transition.name,
              style: context.t.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
  Widget _sep(AppColors c) => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: c.border,
      );
}
