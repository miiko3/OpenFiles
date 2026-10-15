import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/fs_node.dart';
import '../../../data/services/saf_service.dart';
import '../../../widgets/common.dart';
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.node});
  final FsNode node;
  @override
  State<ImageViewer> createState() => _ImageViewerState();
}
class _ImageViewerState extends State<ImageViewer> {
  void _goBack() => Navigator.of(context).pop();

  final _saf = SafService.instance;
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _saf.readBytes(widget.node);
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
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_loading) {
      return FileLoadState(
        onBack: _goBack,
        child: const LoadingOverlay(
          visible: true,
          message: 'Opening image',
        ),
      );
    }
    if (_error != null || _bytes == null) {
      return FileLoadState(
        onBack: _goBack,
        child: EmptyState(
        icon: Icons.broken_image_outlined,
        title: 'Cannot open image',
        message: _error,
          action: PillButton(
            label: 'Повторить',
            primary: true,
            onPressed: _load,
          ),
        ),
      );
    }
    return Column(
      children: [
        _bar(c),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpace.md,
              0,
              AppSpace.md,
              AppSpace.md,
            ),
            decoration: BoxDecoration(
              color: c.canvas,
              borderRadius: AppRadius.lg,
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: PhotoView(
              imageProvider: MemoryImage(_bytes!),
              backgroundDecoration: BoxDecoration(color: c.canvas),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 6,
              heroAttributes: PhotoViewHeroAttributes(tag: 'img-${widget.node.name}'),
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 40),
              ),
            ),
          ),
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
          Text(
            formatBytes(_bytes!.length),
            style: context.t.labelMedium,
          ),
          const SizedBox(width: AppSpace.sm),
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
          RoundIconButton(
            icon: Icons.info_outline_rounded,
            size: 36,
            iconSize: 18,
            tooltip: 'Details',
            onPressed: () => showRoundedSheet<void>(
              context,
              title: widget.node.name,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row('Type', widget.node.mime),
                  _row('Size', formatBytes(_bytes!.length)),
                  _row('Modified', '${widget.node.modified.toLocal()}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(k, style: context.t.bodySmall)),
            Flexible(child: Text(v, style: context.t.bodyMedium)),
          ],
        ),
      );
}
