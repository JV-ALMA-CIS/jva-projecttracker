import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Curated font choices for the Settings > Appearance font picker.
enum AppFont { roboto, inter, poppins, lato, merriweather }

extension AppFontX on AppFont {
  String get label => switch (this) {
    AppFont.roboto => 'Roboto',
    AppFont.inter => 'Inter',
    AppFont.poppins => 'Poppins',
    AppFont.lato => 'Lato',
    AppFont.merriweather => 'Merriweather',
  };

  /// The Google Fonts family name, used to preview this font directly (e.g.
  /// in a `TextStyle(fontFamily: ...)`) without building a whole text theme.
  String get fontFamily => switch (this) {
    AppFont.roboto => GoogleFonts.roboto().fontFamily!,
    AppFont.inter => GoogleFonts.inter().fontFamily!,
    AppFont.poppins => GoogleFonts.poppins().fontFamily!,
    AppFont.lato => GoogleFonts.lato().fontFamily!,
    AppFont.merriweather => GoogleFonts.merriweather().fontFamily!,
  };

  TextTheme apply(TextTheme base) => switch (this) {
    AppFont.roboto => GoogleFonts.robotoTextTheme(base),
    AppFont.inter => GoogleFonts.interTextTheme(base),
    AppFont.poppins => GoogleFonts.poppinsTextTheme(base),
    AppFont.lato => GoogleFonts.latoTextTheme(base),
    AppFont.merriweather => GoogleFonts.merriweatherTextTheme(base),
  };

  static AppFont fromName(String value) {
    return AppFont.values.firstWhere(
      (f) => f.name == value,
      orElse: () => AppFont.roboto,
    );
  }
}
