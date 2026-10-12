import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 40,
    this.iconSize = 20,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = danger
        ? c.danger
        : active
            ? c.primary
            : c.textDim;
    final button = Material(
      color: active ? c.primarySoft : Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.dense = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = primary ? c.primary : c.surfaceAlt;
    final fg = primary ? c.onPrimary : c.text;
    return Material(
      color: bg,
      borderRadius: AppRadius.pill,
      child: InkWell(
        borderRadius: AppRadius.pill,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16,
            vertical: dense ? 7 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 15 : 17, color: fg),
                SizedBox(width: dense ? 6 : 8),
              ],
              Text(
                label,
                style: (dense ? context.t.labelMedium : context.t.labelLarge)
                    ?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class RoundedPanel extends StatelessWidget {
  const RoundedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.color,
    this.border = true,
    this.radius = AppRadius.lg,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool border;
  final BorderRadius radius;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: radius,
        border: border ? Border.all(color: c.border) : null,
      ),
      child: child,
    );
  }
}
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: AppRadius.xl,
              ),
              child: Icon(icon, size: 42, color: c.textFaint),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title, style: context.t.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                message!,
                style: context.t.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        top: AppSpace.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.t.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!, style: context.t.bodySmall),
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Flexible(child: child),
          const SizedBox(height: AppSpace.md),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: AppRadius.pill,
            ),
          ),
        ],
      ),
    );
  }
}
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.visible,
    this.message,
    this.progress,
  });
  final bool visible;
  final String? message;
  final double? progress;
  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final c = context.c;
    return Positioned.fill(
      child: ColoredBox(
        color: c.bg.withValues(alpha: 0.72),
        child: Center(
          child: RoundedPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: progress,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text(message!, style: context.t.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
Future<T?> showRoundedSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  List<Widget>? actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => SheetShell(
      title: title,
      subtitle: subtitle,
      actions: actions,
      child: child,
    ),
  );
}
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.c.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.items});
  final List<Widget> items;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final item in items)
            DefaultTextStyle(
              style: context.t.labelSmall!,
              child: item,
            ),
        ],
      ),
    );
  }
}
