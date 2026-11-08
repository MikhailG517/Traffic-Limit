import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xff070a12);
  static const panel = Color(0xff0b101b);
  static const card = Color(0xff0f1522);
  static const cardHigh = Color(0xff151d2e);
  static const border = Color(0xff1e2840);
  static const text = Color(0xffeef2fb);
  static const muted = Color(0xff8390aa);
  static const blue = Color(0xff5b8cff);
  static const violet = Color(0xff8b5cf6);
  static const cyan = Color(0xff22d3ee);
  static const green = Color(0xff2ee6a6);
  static const red = Color(0xffff5d8f);
  static const amber = Color(0xffffb547);
  static const lightBlue = Color(0xff8fb0ff);

  static const download = cyan;
  static const upload = red;

  static const brandGradient = LinearGradient(
      colors: [cyan, blue, violet],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);
}

/// Colours that differ between the dark and the light theme.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette(
      {required this.background,
      required this.card,
      required this.cardHigh,
      required this.border,
      required this.text,
      required this.muted,
      required this.glow});
  final Color background, card, cardHigh, border, text, muted;
  final double glow;

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    return Palette(
        background: Color.lerp(background, other.background, t)!,
        card: Color.lerp(card, other.card, t)!,
        cardHigh: Color.lerp(cardHigh, other.cardHigh, t)!,
        border: Color.lerp(border, other.border, t)!,
        text: Color.lerp(text, other.text, t)!,
        muted: Color.lerp(muted, other.muted, t)!,
        glow: glow + (other.glow - glow) * t);
  }
}

const _darkPalette = Palette(
    background: AppColors.background,
    card: AppColors.card,
    cardHigh: AppColors.cardHigh,
    border: AppColors.border,
    text: AppColors.text,
    muted: AppColors.muted,
    glow: 1);

const _lightPalette = Palette(
    background: Color(0xfff3f5fb),
    card: Colors.white,
    cardHigh: Color(0xffeef1f9),
    border: Color(0xffdfe4f0),
    text: Color(0xff121828),
    muted: Color(0xff66718a),
    glow: .45);

const _font = 'Manrope';

ThemeData _build(Brightness brightness, Palette p) {
  final base =
      ThemeData(useMaterial3: true, brightness: brightness, fontFamily: _font);
  final scheme =
      ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: brightness)
          .copyWith(
              primary: AppColors.blue,
              secondary: AppColors.cyan,
              surface: p.card,
              onSurface: p.text,
              surfaceContainerHighest: p.cardHigh,
              outline: p.border);
  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    colorScheme: scheme,
    dividerColor: p.border,
    extensions: [p],
    textTheme: base.textTheme
        .apply(fontFamily: _font, bodyColor: p.text, displayColor: p.text),
    cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.border))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle:
                const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: p.text,
            side: BorderSide(color: p.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle:
                const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)))),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : p.muted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.blue
                : p.cardHigh),
        trackOutlineColor: WidgetStateProperty.all(p.border)),
    sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: AppColors.blue,
        thumbColor: Colors.white,
        overlayColor: AppColors.blue.withValues(alpha: .2),
        inactiveTrackColor: p.cardHigh),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardHigh,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.cardHigh,
        contentTextStyle: TextStyle(fontFamily: _font, color: p.text),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: p.border))),
    dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: p.border))),
    tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: p.cardHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border)),
        textStyle: TextStyle(fontFamily: _font, color: p.text, fontSize: 12)),
  );
}

final appTheme = _build(Brightness.dark, _darkPalette);
final lightTheme = _build(Brightness.light, _lightPalette);
