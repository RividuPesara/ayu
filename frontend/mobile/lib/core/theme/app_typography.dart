import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const String primaryFamily = 'Urbanist';
  static const String sinhalaFamily = 'NotoSansSinhala';

  static const List<String> familyFallback = <String>[sinhalaFamily];
}

TextStyle urbanist({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  double? wordSpacing,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? decorationColor,
  double? decorationThickness,
  List<Shadow>? shadows,
  TextBaseline? textBaseline,
  Paint? foreground,
  Color? backgroundColor,
}) {
  return TextStyle(
    fontFamily: AppTypography.primaryFamily,
    fontFamilyFallback: AppTypography.familyFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    fontStyle: fontStyle,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationThickness: decorationThickness,
    shadows: shadows,
    textBaseline: textBaseline,
    foreground: foreground,
    backgroundColor: backgroundColor,
  );
}

extension SinhalaFallbackTextStyle on TextStyle {
  /// Adds the Sinhala fallback to a style built elsewhere.
  TextStyle get withSinhalaFallback =>
      copyWith(fontFamilyFallback: AppTypography.familyFallback);
}
