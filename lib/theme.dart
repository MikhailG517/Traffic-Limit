import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xff0b0f15);
  static const panel = Color(0xff10151c);
  static const card = Color(0xff151b26);
  static const selected = Color(0xff182235);
  static const border = Color(0xff293241);
  static const text = Color(0xffe9eef8);
  static const muted = Color(0xff8994a8);
  static const blue = Color(0xff4f8cff);
  static const cyan = Color(0xff26d3ed);
  static const green = Color(0xff35dfa0);
  static const red = Color(0xffff7182);
  static const lightBlue = Color(0xff82a8ed);
}

final appTheme = ThemeData.dark(useMaterial3: true).copyWith(
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      secondary: AppColors.cyan,
      surface: AppColors.card),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.text, fontSize: 14),
    titleLarge: TextStyle(
        color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 26),
    titleMedium: TextStyle(
        color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16),
  ),
  cardTheme: CardThemeData(
    color: AppColors.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.border)),
  ),
  sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.blue,
      thumbColor: Colors.white,
      overlayColor: Color(0x334f8cff),
      inactiveTrackColor: Color(0xff2a303c)),
);
