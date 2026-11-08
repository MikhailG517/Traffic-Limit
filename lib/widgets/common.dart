import 'package:flutter/material.dart';
import '../theme.dart';
import 'ambient_clock.dart';

class PageShell extends StatelessWidget {
  const PageShell(
      {super.key,
      required this.title,
      required this.child,
      this.subtitle,
      this.action});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6)),
                  if (subtitle != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style:
                                TextStyle(color: palette.muted, fontSize: 13))),
                ])),
            if (action != null) action!
          ]),
          const SizedBox(height: 20),
          Expanded(child: child)
        ]));
  }
}

/// Translucent card with a hairline border and a soft top highlight.
class GlassCard extends StatelessWidget {
  const GlassCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.accent});
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
        padding: padding,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      (accent ?? AppColors.blue)
                          .withValues(alpha: .07 * palette.glow),
                      palette.card.withValues(alpha: .92)),
                  palette.card.withValues(alpha: .82),
                ])),
        child: child);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      GlassCard(padding: padding, child: child);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ]);
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .25))),
      child: Icon(icon, color: color, size: 18));
}

class StatCard extends StatelessWidget {
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.icon,
      this.subtitle,
      this.footer});
  final String label, value;
  final Color color;
  final IconData icon;
  final String? subtitle;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return GlassCard(
        accent: color,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2))),
          ]),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  fontFeatures: [FontFeature.tabularFigures()])),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontSize: 12))),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]));
  }
}

/// Two-colour bar showing the download/upload split of a volume.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.download, required this.upload});
  final double download, upload;
  @override
  Widget build(BuildContext context) {
    final total = download + upload;
    final share = total <= 0 ? 0.0 : download / total;
    return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
            height: 5,
            child: LayoutBuilder(
                builder: (context, c) => Stack(children: [
                      Container(color: Palette.of(context).cardHigh),
                      if (total > 0) ...[
                        Container(width: c.maxWidth, color: AppColors.upload),
                        Container(
                            width: c.maxWidth * share,
                            color: AppColors.download),
                      ]
                    ]))));
  }
}

class LivePill extends StatelessWidget {
  const LivePill({super.key, this.active = true, this.label});
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.amber;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 14,
              height: 14,
              child: RepaintBoundary(
                  child: CustomPaint(painter: _PulsePainter(color)))),
          const SizedBox(width: 8),
          Text(label ?? (active ? 'В ЭФИРЕ' : 'НЕДОСТУПНО'),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 11))
        ]));
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.color) : super(repaint: AmbientClock.instance);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final t = (AmbientClock.instance.seconds / 1.6) % 1;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
        c, 3 + 4 * t, Paint()..color = color.withValues(alpha: (1 - t) * .5));
    canvas.drawCircle(c, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.color != color;
}

/// Pill-style segmented switch with a sliding highlight.
class PillTabs<T> extends StatelessWidget {
  const PillTabs(
      {super.key,
      required this.values,
      required this.selected,
      required this.label,
      required this.onChanged});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: palette.cardHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final value in values)
            GestureDetector(
                onTap: () => onChanged(value),
                child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            gradient: value == selected
                                ? AppColors.brandGradient
                                : null,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(label(value),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: value == selected
                                    ? Colors.white
                                    : palette.muted)))))
        ]));
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow(
      {super.key,
      required this.title,
      required this.description,
      required this.value,
      required this.onChanged,
      this.icon});
  final String title, description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        if (icon != null) ...[
          IconBadge(icon: icon!, color: AppColors.blue),
          const SizedBox(width: 14),
        ],
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(description,
              style: TextStyle(color: Palette.of(context).muted, fontSize: 13))
        ])),
        Switch(value: value, onChanged: onChanged)
      ]));
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .5), blurRadius: 6)
                ])),
        const SizedBox(width: 7),
        Text(text,
            style: TextStyle(color: Palette.of(context).muted, fontSize: 12))
      ]);
}
