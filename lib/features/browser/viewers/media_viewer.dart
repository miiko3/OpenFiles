import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.node, required this.video});
  final FsNode node;
  final bool video;
  @override
  State<MediaViewer> createState() => _MediaViewerState();
}
class _MediaViewerState extends State<MediaViewer> {
  final _saf = SafService.instance;
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  String? _path;
  String? _error;
  bool _loading = true;
  bool _videoReady = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  @override
  void dispose() {
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await _saf.materialize(widget.node);
      if (!mounted) return;
      if (widget.video) {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        await controller.setLooping(false);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _video = controller;
          _path = path;
          _loading = false;
          _videoReady = true;
        });
      } else {
        final player = AudioPlayer();
        final source = File(path);
        await player.setFilePath(path);
        final length = player.duration;
        await player.play();
        if (!mounted) return;
        setState(() {
          _audio = player;
          _path = path;
          _loading = false;
        });
        player.positionStream.listen((_) {
          if (mounted) setState(() {});
        });
        player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            player.seek(Duration.zero);
            player.play();
          }
          if (mounted) setState(() {});
        });
        _lastDuration = length;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
  Duration? _lastDuration;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) {
      return const LoadingOverlay(visible: true, message: 'Loading media');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cannot play ${widget.node.name}',
        message: _error,
        action: PillButton(label: 'Повторить', primary: true, onPressed: _load),
      );
    }
    return Column(
      children: [
        _bar(c),
        Expanded(
          child: widget.video ? _videoPane(c) : _audioPane(c),
        ),
      ],
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
          Expanded(
            child: Text(
              widget.node.name,
              style: context.t.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          RoundIconButton(
            icon: Icons.ios_share_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Поделиться',
            onPressed: () async {
              final path = await _saf.materialize(widget.node);
              if (!context.mounted) return;
              await _saf.shareLocal(path, widget.node.mime);
            },
          ),
        ],
      ),
    );
  }
  Widget _videoPane(AppColors c) {
    final controller = _video;
    if (controller == null || !_videoReady) {
      return Center(child: Text('Preparing', style: context.t.bodySmall));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: Container(
        margin: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: AppRadius.lg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => AnimatedOpacity(
                opacity: value.isPlaying ? 0 : 1,
                duration: AppDuration.normal,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xB3000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 38),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: c.primary,
                  bufferedColor: c.outline,
                  backgroundColor: c.surfaceAlt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _audioPane(AppColors c) {
    final player = _audio;
    if (player == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, c.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.xl,
            ),
            child: const Icon(Icons.music_note_rounded, size: 66, color: Colors.white),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            widget.node.name,
            style: context.t.titleLarge,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            widget.node.extension.toUpperCase(),
            style: context.t.labelMedium,
          ),
          const SizedBox(height: AppSpace.xl),
          Slider(
            value: player.position.inMilliseconds.clamp(
              0,
              player.duration?.inMilliseconds ?? 1,
            ).toDouble(),
            max: (player.duration?.inMilliseconds ?? 1).toDouble(),
            onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(player.position), style: context.t.labelMedium),
              Text(_fmt(player.duration ?? _lastDuration), style: context.t.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundIconButton(
                icon: Icons.replay_10_rounded,
                size: 46,
                tooltip: 'Назад 10 секунд',
                onPressed: () => player.seek(
                  player.position - const Duration(seconds: 10),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              RoundIconButton(
                icon: player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 68,
                iconSize: 34,
                active: true,
                tooltip: player.playing ? 'Pause' : 'Play',
                onPressed: () {
                  if (player.playing) {
                    player.pause();
                  } else {
                    player.play();
                  }
                  setState(() {});
                },
              ),
              const SizedBox(width: AppSpace.lg),
              RoundIconButton(
                icon: Icons.forward_30_rounded,
                size: 46,
                tooltip: 'Вперёд 30 секунд',
                onPressed: () => player.seek(
                  player.position + const Duration(seconds: 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  static String _fmt(Duration? d) {
    if (d == null) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
