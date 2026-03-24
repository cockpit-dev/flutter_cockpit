import 'package:flutter/material.dart';

final class OrbitTodoTheme {
  const OrbitTodoTheme._();

  static ThemeData build(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF8FB8AE),
            onPrimary: Color(0xFF0F1716),
            primaryContainer: Color(0xFF172624),
            onPrimaryContainer: Color(0xFFD5E7E2),
            secondary: Color(0xFFC8B79D),
            onSecondary: Color(0xFF1D1711),
            secondaryContainer: Color(0xFF2A221A),
            onSecondaryContainer: Color(0xFFF2E6D6),
            tertiary: Color(0xFFA7B9C8),
            onTertiary: Color(0xFF0E171F),
            tertiaryContainer: Color(0xFF1B2731),
            onTertiaryContainer: Color(0xFFDFE9F1),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: Color(0xFF101415),
            onSurface: Color(0xFFF3EFE8),
            onSurfaceVariant: Color(0xFFB3ADA4),
            outline: Color(0xFF5B6463),
            outlineVariant: Color(0xFF1E2325),
            shadow: Color(0xFF000000),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFFF3EFE8),
            onInverseSurface: Color(0xFF171A1C),
            inversePrimary: Color(0xFF244A44),
            surfaceDim: Color(0xFF0A0D0E),
            surfaceBright: Color(0xFF171C1E),
            surfaceContainerLowest: Color(0xFF090B0C),
            surfaceContainerLow: Color(0xFF0E1213),
            surfaceContainer: Color(0xFF13191A),
            surfaceContainerHigh: Color(0xFF181E20),
            surfaceContainerHighest: Color(0xFF1D2426),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF214F47),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFDCE7E1),
            onPrimaryContainer: Color(0xFF142725),
            secondary: Color(0xFF6D5A43),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFF0E6D6),
            onSecondaryContainer: Color(0xFF2D241A),
            tertiary: Color(0xFF425C72),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFD8E4ED),
            onTertiaryContainer: Color(0xFF1C2A36),
            error: Color(0xFFBA1A1A),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFF6F1E8),
            onSurface: Color(0xFF171A1C),
            onSurfaceVariant: Color(0xFF676961),
            outline: Color(0xFFA5A69C),
            outlineVariant: Color(0xFFDAD3C9),
            shadow: Color(0xFF000000),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFF171A1C),
            onInverseSurface: Color(0xFFF0ECE4),
            inversePrimary: Color(0xFF9CC2B8),
            surfaceDim: Color(0xFFE8E0D4),
            surfaceBright: Color(0xFFFCF8F1),
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: Color(0xFFF7F2E8),
            surfaceContainer: Color(0xFFF1EBE0),
            surfaceContainerHigh: Color(0xFFEBE4D8),
            surfaceContainerHighest: Color(0xFFE2DBCF),
          );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );
    const bodyFontFamily = 'Manrope';
    const displayFontFamily = 'SpaceGrotesk';
    final bodyTextTheme = baseTheme.textTheme.apply(
      fontFamily: bodyFontFamily,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final textTheme = bodyTextTheme.copyWith(
      displayLarge: bodyTextTheme.displayLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.3,
      ),
      displayMedium: bodyTextTheme.displayMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineLarge: bodyTextTheme.headlineLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: bodyTextTheme.headlineMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineSmall: bodyTextTheme.headlineSmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: bodyTextTheme.titleLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: bodyTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      labelLarge: bodyTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0C1112)
          : const Color(0xFFF7F2E9),
      canvasColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0C1112)
            : const Color(0xFFF7F2E9),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: bodyFontFamily,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlphaFraction(0.9),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.only(
          left: 0,
          right: 0,
          top: 14,
          bottom: 14,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.65),
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.65),
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.35),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colorScheme.error, width: 1.35),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: Colors.transparent,
        selectedColor: brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLow,
        disabledColor: Colors.transparent,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.45,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        iconColor: colorScheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colorScheme.outline, width: 1.3),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: textTheme.bodyLarge),
    );
  }

  static Gradient screenGlow(Brightness brightness) {
    return brightness == Brightness.dark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF111516), Color(0xFF0D1112)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF6F1E8), Color(0xFFF1EBE1)],
          );
  }

  static LinearGradient heroPanelGradient(ThemeData theme) {
    final scheme = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[scheme.surfaceContainer, scheme.surfaceContainerLow],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[scheme.surface, scheme.surfaceContainerLow],
    );
  }

  static LinearGradient accentPanelGradient(
    ThemeData theme, {
    required Color accent,
  }) {
    if (theme.brightness == Brightness.dark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withAlphaFraction(0.08),
          theme.colorScheme.surfaceContainerLow,
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        accent.withAlphaFraction(0.05),
        theme.colorScheme.surface,
      ],
    );
  }
}

extension OrbitTodoThemeTokens on ThemeData {
  bool get isEditorialDark => brightness == Brightness.dark;

  Color get editorialSurfaceColor =>
      isEditorialDark ? colorScheme.surfaceContainerHigh : colorScheme.surface;

  Color get editorialMutedSurfaceColor => isEditorialDark
      ? colorScheme.surfaceContainer
      : colorScheme.surfaceContainerLow;

  Color get editorialRaisedSurfaceColor => isEditorialDark
      ? colorScheme.surfaceContainerHighest
      : colorScheme.surfaceContainer;

  Color get editorialChromeColor => isEditorialDark
      ? colorScheme.surfaceBright
      : colorScheme.surfaceContainerHigh;
}

extension OrbitTodoColorAlpha on Color {
  Color withAlphaFraction(double alpha) {
    final normalized = alpha.clamp(0.0, 1.0);
    return withAlpha((normalized * 255).round());
  }
}
