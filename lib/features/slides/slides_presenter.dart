import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/tokens.dart';
import 'pptx_codec.dart' as ppt;
import '../browser/viewers/slides_painter.dart';
class SlidesPresenter extends StatefulWidget {
  const SlidesPresenter({
    super.key,
    required this.deck,
    this.startIndex = 0,
  });
  final ppt.SlideDeck deck;
  final int startIndex;
  @override
  State<SlidesPresenter> createState() => _SlidesPresenterState();
}
class _SlidesPresenterState extends State<SlidesPresenter> {
  late int _index = widget.startIndex;
  final Stopwatch _clock = Stopwatch()..start();
  bool _blackScreen = false;
  bool _whiteScreen = false;
  bool _chrome = true;
  @override
  void dispose() {
    _clock.stop();
    super.dispose();
  }
  void _next() {
    if (_index < widget.deck.slides.length - 1) {
      setState(() => _index++);
    }
  }
  void _previous() {
    if (_index > 0) setState(() => _index--);
  }
  String get _elapsed {
    final seconds = _clock.elapsed.inSeconds;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowRight:
            case LogicalKeyboardKey.space:
            case LogicalKeyboardKey.pageDown:
              _next();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowLeft:
            case LogicalKeyboardKey.pageUp:
              _previous();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.escape:
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.keyB:
              setState(() {
                _blackScreen = !_blackScreen;
                _whiteScreen = false;
              });
              return KeyEventResult.handled;
            case LogicalKeyboardKey.keyW:
              setState(() {
                _whiteScreen = !_whiteScreen;
                _blackScreen = false;
              });
              return KeyEventResult.handled;
            case LogicalKeyboardKey.f5:
              setState(() => _chrome = !_chrome);
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _next,
          onDoubleTap: () => setState(() => _chrome = !_chrome),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: AppDuration.normal,
                  child: _blackScreen || _whiteScreen
                      ? ColoredBox(
                          key: ValueKey(_blackScreen ? 'b' : 'w'),
                          color: _blackScreen ? Colors.black : Colors.white,
                        )
                      : Center(
                          key: ValueKey(_index),
                          child: _slideWidget(),
                        ),
                ),
              ),
              if (_chrome) _overlay(c),
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                        onPressed: _previous,
                      ),
                      Text(
                        '${_index + 1} / ${widget.deck.slides.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        onPressed: _next,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _slideWidget() {
    final ratio = widget.deck.widthPt / widget.deck.heightPt;
    return LayoutBuilder(
      builder: (context, box) {
        var width = box.maxWidth;
        var height = width / ratio;
        if (height > box.maxHeight) {
          height = box.maxHeight;
          width = height * ratio;
        }
        return AnimatedSwitcher(
          duration: Duration(
            milliseconds: (_slide.transitionDuration * 1000).round().clamp(80, 2400),
          ),
          transitionBuilder: (child, animation) => _transition(child, animation),
          child: Container(
            key: ValueKey(_index),
            width: width,
            height: height,
            color: Colors.white,
            child: CustomPaint(
              painter: SlidePainter(
                slide: _slide,
                deckWidth: widget.deck.widthPt,
                deckHeight: widget.deck.heightPt,
                images: const {},
              ),
            ),
          ),
        );
      },
    );
  }
  ppt.Slide get _slide => widget.deck.slides[_index.clamp(0, widget.deck.slides.length - 1)];
  Widget _transition(Widget child, Animation<double> animation) {
    switch (_slide.transition) {
      case ppt.SlideTransition.fade:
      case ppt.SlideTransition.dissolve:
        return FadeTransition(opacity: animation, child: child);
      case ppt.SlideTransition.push:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case ppt.SlideTransition.wipe:
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: animation.value,
            child: child,
          ),
        );
      case ppt.SlideTransition.cover:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case ppt.SlideTransition.reveal:
      case ppt.SlideTransition.unCover:
        return ClipRect(
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: animation.value,
            child: child,
          ),
        );
      case ppt.SlideTransition.zoom:
        return ScaleTransition(scale: animation, child: child);
      case ppt.SlideTransition.flip:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, inner) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(animation.value * math.pi),
            child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: inner),
          ),
          child: child,
        );
      case ppt.SlideTransition.split:
      case ppt.SlideTransition.doors:
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: math.max(animation.value, 0.0001),
            child: child,
          ),
        );
      default:
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: child,
        );
    }
  }
  Widget _overlay(AppColors c) {
    final next = _index + 1 < widget.deck.slides.length
        ? widget.deck.slides[_index + 1]
        : null;
    return Positioned(
      left: AppSpace.lg,
      top: AppSpace.lg,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.94,
          child: Container(
            width: 210,
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: AppRadius.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEXT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                SizedBox(
                  height: 62,
                  child: next == null
                      ? Center(
                          child: Text(
                            'End of deck',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        )
                      : CustomPaint(
                          painter: SlidePainter(
                            slide: next,
                            deckWidth: widget.deck.widthPt,
                            deckHeight: widget.deck.heightPt,
                            images: const {},
                            scaleOverride: 186 / widget.deck.widthPt,
                          ),
                          size: const Size(186, 62),
                        ),
                ),
                if (_slide.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    _slide.notes,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                Text(
                  '$_elapsed  ·  ${_index + 1}/${widget.deck.slides.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}