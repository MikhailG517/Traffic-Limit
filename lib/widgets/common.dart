import 'package:flutter/material.dart';
import '../theme.dart';

class PageShell extends StatelessWidget {
  const PageShell(
      {super.key, required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (action != null) action!
        ]),
        const SizedBox(height: 22),
        Expanded(child: child)
      ]));
}

class StatCard extends StatelessWidget {
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.icon,
      this.subtitle});
  final String label, value;
  final Color color;
  final IconData icon;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21)),
            const SizedBox(height: 15),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5)),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 25, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12))
          ])));
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
      Card(child: Padding(padding: padding, child: child));
}

class LivePill extends StatelessWidget {
  const LivePill({super.key, this.active = true});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
          color: active
              ? AppColors.green.withOpacity(.1)
              : Colors.orange.withOpacity(.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: active
                  ? AppColors.green.withOpacity(.45)
                  : Colors.orange.withOpacity(.45))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle,
            size: 9, color: active ? AppColors.green : Colors.orange),
        const SizedBox(width: 8),
        Text(active ? 'В ЭФИРЕ' : 'ОГРАНИЧЕНИЕ НЕДОСТУПНО',
            style: TextStyle(
                color: active ? AppColors.green : Colors.orange,
                fontWeight: FontWeight.w700,
                fontSize: 12))
      ]));
}

class ToggleRow extends StatelessWidget {
  const ToggleRow(
      {super.key,
      required this.title,
      required this.description,
      required this.value,
      required this.onChanged});
  final String title, description;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(color: AppColors.muted, fontSize: 13))
        ])),
        Switch(value: value, onChanged: onChanged)
      ]));
}
