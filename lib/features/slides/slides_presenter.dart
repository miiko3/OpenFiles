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
                      : SizedBox.expand(
                          key: ValueKey(_index),
                          child: _slideWidget(),
                        ),
                ),
              ),
              if (_chrome)
                Positioned(
                  left: AppSpace.lg,
                  top: AppSpace.lg,
                  child: Text(
                    '$_elapsed',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
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
        var width = box.maxWidth - 16;
        var height = width / ratio;
        if (height > box.maxHeight - 16) {
          height = box.maxHeight - 16;
          width = height * ratio;
        }
        final slackX = math.max(0.0, box.maxWidth - width);
        final slackY = math.max(0.0, box.maxHeight - height);
        return AnimatedSwitcher(
          duration: Duration(
            milliseconds: (_slide.transitionDuration * 1000).round().clamp(80, 2400),
          ),
          transitionBuilder: (child, animation) => _transition(child, animation),
          child: Center(
            child: Transform.translate(
              key: ValueKey(_index),
              offset: Offset(slackX * 0.12, slackY * 0.18),
              child: Container(
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
        return _reveal(animation, child, fromLeft: true);
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
        return _reveal(animation, child, fromLeft: false);
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
        return _reveal(animation, child, bothSides: true);
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
}

class _RevealClip extends CustomClipper<Rect> {
  const _RevealClip({required this.t, this.fromLeft = false, this.bothSides = false});

  final double t;
  final bool fromLeft;
  final bool bothSides;

  @override
  Rect getClip(Size size) {
    final v = t.clamp(0.0, 1.0);
    if (bothSides) {
      final inset = size.width * (1 - v) / 2;
      return Rect.fromLTRB(inset, 0, size.width - inset, size.height);
    }
    final w = size.width * v;
    if (fromLeft) return Rect.fromLTWH(0, 0, w, size.height);
    return Rect.fromLTWH(size.width - w, 0, w, size.height);
  }

  @override
  bool shouldReclip(_RevealClip oldClipper) => oldClipper.t != t;
}

Widget _reveal(
  Animation<double> animation,
  Widget child, {
  bool fromLeft = false,
  bool bothSides = false,
}) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, inner) => ClipRect(
      clipper: _RevealClip(
        t: animation.value,
        fromLeft: fromLeft,
        bothSides: bothSides,
      ),
      child: inner,
    ),
    child: child,
  );
}
