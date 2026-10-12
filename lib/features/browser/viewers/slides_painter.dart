import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../slides/pptx_codec.dart';
class SlidePainter extends CustomPainter {
  SlidePainter({
    required this.slide,
    required this.deckWidth,
    required this.deckHeight,
    required this.images,
    this.selectedId,
    this.scaleOverride,
  });
  final Slide slide;
  final double deckWidth;
  final double deckHeight;
  final Map<String, ui.Image> images;
  final String? selectedId;
  final double? scaleOverride;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = scaleOverride ?? (deckWidth == 0 ? 1 : size.width / deckWidth);
    final background = Paint()
      ..style = PaintingStyle.fill
      ..color = Color(slide.background ?? 0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, background);
    for (final element in slide.elements) {
      canvas.save();
      canvas.translate(element.x * scale, element.y * scale);
      if (element.rotation != 0) {
        canvas.translate(element.w * scale / 2, element.h * scale / 2);
        canvas.rotate(element.rotation * math.pi / 180);
        canvas.translate(-element.w * scale / 2, -element.h * scale / 2);
      }
      final rect = Rect.fromLTWH(0, 0, element.w * scale, element.h * scale);
      switch (element) {
        case final SlideText value:
          drawText(canvas, rect, value.style, value.text, scale);
        case final SlideShapeEl value:
          drawShape(canvas, rect, value, scale);
        case final SlidePicture value:
          final image = images[value.id];
          if (image != null) {
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
              rect,
              Paint()..filterQuality = FilterQuality.medium,
            );
          } else {
            final placeholder = Paint()..color = const Color(0xFFE6DACB);
            canvas.drawRect(rect, placeholder);
          }
        case final SlideTableEl value:
          drawTable(canvas, rect, value, scale);
      }
      canvas.restore();
      if (element.id == selectedId) {
        final outline = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFC08163);
        canvas.drawRect(
          Rect.fromLTWH(
            element.x * scale,
            element.y * scale,
            element.w * scale,
            element.h * scale,
          ),
          outline,
        );
        final handle = Paint()..color = const Color(0xFFC08163);
        for (final point in [
          Offset(element.x * scale, element.y * scale),
          Offset((element.x + element.w) * scale, element.y * scale),
          Offset(element.x * scale, (element.y + element.h) * scale),
          Offset((element.x + element.w) * scale, (element.y + element.h) * scale),
        ]) {
          canvas.drawRect(Rect.fromCenter(center: point, width: 7, height: 7), handle);
        }
      }
    }
  }
  void drawShape(Canvas canvas, Rect rect, SlideShapeEl element, double scale) {
    final path = shapePath(element.shape, rect);
    canvas.drawPath(path, Paint()..color = Color(element.fill));
    if (element.lineWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(element.lineWidth * scale, 0.5)
          ..color = Color(element.line),
      );
    }
    if (element.text.isNotEmpty) {
      drawText(canvas, rect, element.style, element.text, scale);
    }
  }
  Path shapePath(SlideShape shape, Rect rect) {
    final path = Path();
    switch (shape) {
      case SlideShape.rectangle:
        path.addRect(rect);
      case SlideShape.roundedRect:
        path.addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(rect.shortestSide * 0.18),
          ),
        );
      case SlideShape.ellipse:
        path.addOval(rect);
      case SlideShape.triangle:
        path.moveTo(rect.center.dx, rect.top);
        path.lineTo(rect.right, rect.bottom);
        path.lineTo(rect.left, rect.bottom);
        path.close();
      case SlideShape.line:
        path.moveTo(rect.left, rect.center.dy);
        path.lineTo(rect.right, rect.center.dy);
      case SlideShape.rightArrow:
        path.moveTo(rect.left, rect.top + rect.height * 0.3);
        path.lineTo(rect.left + rect.width * 0.55, rect.top + rect.height * 0.3);
        path.lineTo(rect.left + rect.width * 0.55, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.left + rect.width * 0.55, rect.bottom);
        path.lineTo(rect.left + rect.width * 0.55, rect.bottom - rect.height * 0.3);
        path.lineTo(rect.left, rect.bottom - rect.height * 0.3);
        path.close();
      case SlideShape.star:
        final points = <Offset>[];
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? rect.shortestSide / 2 : rect.shortestSide / 4;
          final angle = -math.pi / 2 + i * math.pi / 5;
          points.add(
            Offset(
              rect.center.dx + radius * math.cos(angle),
              rect.center.dy + radius * math.sin(angle),
            ),
          );
        }
        path.addPolygon(points, true);
      case SlideShape.hexagon:
        path.moveTo(rect.left + rect.width * 0.25, rect.top);
        path.lineTo(rect.right - rect.width * 0.25, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.right - rect.width * 0.25, rect.bottom);
        path.lineTo(rect.left + rect.width * 0.25, rect.bottom);
        path.lineTo(rect.left, rect.center.dy);
        path.close();
      case SlideShape.diamond:
        path.moveTo(rect.center.dx, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.center.dx, rect.bottom);
        path.lineTo(rect.left, rect.center.dy);
        path.close();
      case SlideShape.chevron:
        path.moveTo(rect.left, rect.top);
        path.lineTo(rect.right - rect.width * 0.2, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.right - rect.width * 0.2, rect.bottom);
        path.lineTo(rect.left, rect.bottom);
        path.lineTo(rect.left + rect.width * 0.2, rect.center.dy);
        path.close();
      case SlideShape.callout:
        path.addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(rect.shortestSide * 0.1),
          ),
        );
        path.moveTo(rect.left + rect.width * 0.2, rect.bottom);
        path.lineTo(rect.left + rect.width * 0.1, rect.bottom + rect.height * 0.2);
        path.lineTo(rect.left + rect.width * 0.34, rect.bottom);
        path.close();
    }
    return path;
  }
  void drawTable(Canvas canvas, Rect rect, SlideTableEl element, double scale) {
    if (element.rows.isEmpty) return;
    final rowHeight = rect.height / element.rows.length;
    final columns = element.rows.first.isEmpty ? 1 : element.rows.first.length;
    final colWidth = rect.width / columns;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFD6C7B4);
    for (var r = 0; r < element.rows.length; r++) {
      for (var c = 0; c < element.rows[r].length; c++) {
        final cellRect = Rect.fromLTWH(
          c * colWidth,
          r * rowHeight,
          colWidth,
          rowHeight,
        );
        canvas.drawRect(cellRect, line);
        drawText(
          canvas,
          cellRect.deflate(3),
          const SlideTextStyle(fontSize: 11, color: 0xFF3B332C),
          element.rows[r][c],
          scale,
        );
      }
    }
  }
  void drawText(
    Canvas canvas,
    Rect rect,
    SlideTextStyle style,
    String text,
    double scale,
  ) {
    if (text.isEmpty) return;
    final fontSize = (style.fontSize * scale).clamp(4.0, 160.0);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: switch (style.align) {
          SlideTextAlign.center => TextAlign.center,
          SlideTextAlign.right => TextAlign.right,
          SlideTextAlign.justify => TextAlign.justify,
          _ => TextAlign.left,
        },
        textDirection: TextDirection.ltr,
        fontSize: fontSize,
        fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
        fontFamily: style.fontFamily,
        maxLines: (rect.height / (fontSize * 1.25)).floor().clamp(1, 400),
        ellipsis: '...',
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Color(style.color),
          fontSize: fontSize,
          fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
          decoration: style.underline ? TextDecoration.underline : null,
        ),
      )
      ..addText(text);
    final paragraph = builder.build();
    var dy = switch (style.valign) {
      SlideVAlign.middle => (rect.height - paragraph.height) / 2,
      SlideVAlign.bottom => rect.height - paragraph.height,
      _ => 0.0,
    };
    if (dy < 0) dy = 0;
    canvas.drawParagraph(paragraph, Offset(rect.left, rect.top + dy));
  }
  @override
  bool shouldRepaint(SlidePainter oldDelegate) => true;
}
