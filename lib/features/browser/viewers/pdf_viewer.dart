import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
enum PdfTool { navigate, highlight, underline, strikeout, note, freehand, erase }
class PdfMark {
  PdfMark({
    required this.page,
    required this.tool,
    required this.points,
    required this.color,
  });
  final int page;
  final PdfTool tool;
  final List<Offset> points;
  final Color color;
}
class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key, required this.node, this.allowEdit = true});
  final FsNode node;
  final bool allowEdit;
  @override
  State<PdfViewer> createState() => _PdfViewerState();
}
class _PdfViewerState extends State<PdfViewer> {
  final _saf = SafService.instance;
  final List<PdfMark> _marks = [];
  final List<Offset> _current = [];
  final Map<int, Rect> _pageRects = {};
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  pdfrx.PdfViewerController? _controller;
  int _page = 1;
  int _pageCount = 1;
  int _activePage = 1;
  PdfTool _tool = PdfTool.navigate;
  Color _color = const Color(0xFFD08A4E);
  double _stroke = 3;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(
        widget.node,
        maxBytes: 128 * 1024 * 1024,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  Offset? _normalize(Rect rect, Offset local) {
    if (rect.width <= 0 || rect.height <= 0) return null;
    return Offset(
      (local.dx - rect.left) / rect.width,
      (local.dy - rect.top) / rect.height,
    );
  }
  Rect _pageRectFor(int page) => _pageRects[page] ?? Rect.zero;
  void _undoMark() {
    if (_marks.isEmpty) return;
    setState(() => _marks.removeLast());
  }
  Future<void> _share() async {
    final path = await _saf.materialize(widget.node);
    if (!mounted) return;
    await _saf.shareLocal(path, widget.node.mime);
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) return const LoadingOverlay(visible: true, message: 'Opening PDF');
    if (_error != null || _bytes == null) {
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Cannot open ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    return Column(
      children: [
        _bar(c),
        Expanded(
          child: GestureDetector(
            onTapUp: widget.allowEdit && _tool != PdfTool.navigate
                ? (details) {
                    final point = details.localPosition;
                    for (final entry in _pageRects.entries) {
                      if (!entry.value.contains(point)) continue;
                      final normalized = _normalize(entry.value, point);
                      if (normalized == null) continue;
                      if (_tool == PdfTool.erase) {
                        setState(() {
                          _marks.removeWhere(
                            (m) => m.page == entry.key &&
                                m.points.any((p) => (p - normalized).distance < 0.04),
                          );
                        });
                      } else if (_tool == PdfTool.note) {
                        setState(() {
                          _marks.add(
                            PdfMark(
                              page: entry.key,
                              tool: PdfTool.note,
                              points: [normalized],
                              color: _color,
                            ),
                          );
                          _tool = PdfTool.navigate;
                        });
                      }
                      return;
                    }
                  }
                : null,
            onPanStart: widget.allowEdit && _isDrawing(_tool)
                ? (details) {
                    final point = _hitPage(details.localPosition);
                    final normalized = point == null
                        ? null
                        : _normalize(_pageRectFor(point), details.localPosition);
                    if (normalized != null) {
                      setState(() => _current.add(normalized));
                    }
                  }
                : null,
            onPanUpdate: widget.allowEdit && _isDrawing(_tool)
                ? (details) {
                    final point = _hitPage(details.localPosition);
                    final normalized = point == null
                        ? null
                        : _normalize(_pageRectFor(point), details.localPosition);
                    if (normalized != null) {
                      setState(() => _current.add(normalized));
                    }
                  }
                : null,
            onPanEnd: widget.allowEdit && _isDrawing(_tool)
                ? (details) {
                    final page = _hitPage(details.localPosition);
                    if (_current.length > 1 && page != null) {
                      setState(() {
                        _marks.add(
                          PdfMark(
                            page: page,
                            tool: _tool,
                            points: List.of(_current),
                            color: _color,
                          ),
                        );
                        _current.clear();
                        _tool = PdfTool.navigate;
                      });
                    } else {
                      setState(() => _current.clear());
                    }
                  }
                : null,
            child: pdfrx.PdfViewer.data(
              _bytes!,
              sourceName: widget.node.name,
              params: pdfrx.PdfViewerParams(
                backgroundColor: c.canvas,
                margin: 12,
                pageDropShadow: BoxShadow(
                  color: c.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                onViewerReady: (document, controller) {
                  _controller = controller;
                  _pageCount = document.pages.length;
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber != null && pageNumber != _activePage) {
                    setState(() => _activePage = pageNumber);
                  }
                },
                pageOverlaysBuilder: (context, pageRect, page) {
                  _pageRects[page.pageNumber] = pageRect;
                  final layers = <Widget>[];
                  for (final mark in _marks.where((m) => m.page == page.pageNumber)) {
                    layers.add(_paintMark(mark, pageRect));
                  }
                  if (_current.isNotEmpty && _hitPage(pageRect.topLeft) == page.pageNumber) {
                    layers.add(
                      _paintMark(
                        PdfMark(
                          page: page.pageNumber,
                          tool: _tool,
                          points: List.of(_current),
                          color: _color,
                        ),
                        pageRect,
                      ),
                    );
                  }
                  return layers;
                },
              ),
            ),
          ),
        ),
        StatusBar(
          items: [
            Text('Page $_activePage / $_pageCount'),
            const Spacer(),
            Text('${_marks.length} marks'),
            const Spacer(),
            RoundIconButton(
              icon: Icons.chevron_left_rounded,
              size: 24,
              iconSize: 16,
              tooltip: 'Назад',
              onPressed: () => _controller?.goToPage(pageNumber: _activePage > 1 ? _activePage - 1 : 1),
            ),
            RoundIconButton(
              icon: Icons.chevron_right_rounded,
              size: 24,
              iconSize: 16,
              tooltip: 'Вперёд',
              onPressed: () => _controller?.goToPage(pageNumber: _activePage < _pageCount ? _activePage + 1 : _pageCount),
            ),
          ],
        ),
        if (widget.allowEdit) _toolbar(c),
      ],
    );
  }
  static bool _isDrawing(PdfTool tool) =>
      tool == PdfTool.highlight ||
      tool == PdfTool.underline ||
      tool == PdfTool.strikeout ||
      tool == PdfTool.freehand;
  int? _hitPage(Offset point) {
    for (final entry in _pageRects.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    return null;
  }
  Widget _paintMark(PdfMark mark, Rect rect) {
    if (mark.tool == PdfTool.note) {
      final p = mark.points.first;
      return Positioned(
        left: rect.left + p.dx * rect.width - 11,
        top: rect.top + p.dy * rect.height - 11,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: mark.color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sticky_note_2_rounded, size: 13, color: Colors.white),
        ),
      );
    }
    final points = mark.points
        .map((p) => Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height))
        .toList(growable: false);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: PdfStrokePainter(
            points: points,
            color: mark.color,
            width: _stroke,
            tool: mark.tool,
          ),
        ),
      ),
    );
  }
  Widget _bar(AppColors c) {
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
            size: 36,
            iconSize: 16,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpace.sm),
          const Icon(Icons.picture_as_pdf_outlined, size: 18),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              widget.node.name,
              style: context.t.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          RoundIconButton(
            icon: Icons.first_page_rounded,
            size: 34,
            iconSize: 18,
            tooltip: 'На первую',
            onPressed: () => _controller?.goToPage(pageNumber: 1),
          ),
          RoundIconButton(
            icon: Icons.ios_share_rounded,
            size: 34,
            iconSize: 18,
            tooltip: 'Поделиться',
            onPressed: _share,
          ),
        ],
      ),
    );
  }
  Widget _toolbar(AppColors c) {
    const tools = [
      (PdfTool.navigate, Icons.pan_tool_alt_outlined, 'Navigate'),
      (PdfTool.highlight, Icons.brush_rounded, 'Highlight'),
      (PdfTool.underline, Icons.horizontal_rule_rounded, 'Underline'),
      (PdfTool.strikeout, Icons.strikethrough_s_rounded, 'Strike out'),
      (PdfTool.note, Icons.sticky_note_2_outlined, 'Note'),
      (PdfTool.freehand, Icons.gesture_rounded, 'Draw'),
      (PdfTool.erase, Icons.cleaning_services_outlined, 'Erase'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in tools)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.xs),
                      child: RoundIconButton(
                        icon: entry.$2,
                        active: _tool == entry.$1,
                        tooltip: entry.$3,
                        onPressed: () => setState(() => _tool = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _dot(const Color(0xFFE8C15A)),
          _dot(const Color(0xFF7FB77E)),
          _dot(const Color(0xFFD0726A)),
          _dot(const Color(0xFF6E9CC4)),
          RoundIconButton(
            icon: Icons.undo_rounded,
            size: 34,
            iconSize: 17,
            tooltip: 'Undo mark',
            onPressed: _marks.isEmpty ? null : _undoMark,
          ),
        ],
      ),
    );
  }
  Widget _dot(Color color) {
    final active = _color.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _color = color),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: active ? Border.all(color: context.c.text, width: 2) : null,
        ),
      ),
    );
  }
}
class PdfStrokePainter extends CustomPainter {
  PdfStrokePainter({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });
  final List<Offset> points;
  final Color color;
  final double width;
  final PdfTool tool;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final shifted = switch (tool) {
      PdfTool.underline => _offsetAll(width * 3),
      PdfTool.strikeout => _offsetAll(-width * 2),
      _ => points,
    };
    final path = Path()..moveTo(shifted.first.dx, shifted.first.dy);
    for (final p in shifted.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (shifted.length == 1) {
      path.addOval(Rect.fromCircle(center: shifted.first, radius: width * 0.5));
    }
    if (tool == PdfTool.highlight) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.32)
          ..strokeWidth = width * 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..blendMode = BlendMode.multiply,
      );
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width * 0.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }
  List<Offset> _offsetAll(double dy) =>
      points.map((p) => Offset(p.dx, p.dy + dy)).toList(growable: false);
  @override
  bool shouldRepaint(PdfStrokePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
