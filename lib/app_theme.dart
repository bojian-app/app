import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';

const brandBlue = Color(0xFF2867EE);

enum AppAccent {
  blue('最优简蓝', brandBlue),
  warm('珊瑚暖色', Color(0xFFC64350));

  const AppAccent(this.label, this.seed);
  final String label;
  final Color seed;
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    this.palette = AppAccent.blue,
    required this.canvas,
    required this.surface,
    required this.inset,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warningSoft,
  });

  final AppAccent palette;
  final Color canvas, surface, inset, ink, muted, border;
  final Color accent, accentSoft, success, successSoft, warningSoft;

  static const light = AppColors(
    canvas: Colors.white,
    surface: Colors.white,
    inset: Color(0xFFF3F5F8),
    ink: Color(0xFF202C41),
    muted: Color(0xFF8A94A5),
    border: Color(0xFFEEF0F4),
    accent: brandBlue,
    accentSoft: Color(0xFFEAF1FF),
    success: Color(0xFF408C77),
    successSoft: Color(0xFFF4F8F6),
    warningSoft: Color(0xFFFFF4E5),
  );

  static const dark = AppColors(
    canvas: Color(0xFF111418),
    surface: Color(0xFF1B2027),
    inset: Color(0xFF252C35),
    ink: Color(0xFFE5EAF2),
    muted: Color(0xFFA2ADBD),
    border: Color(0xFF343D49),
    accent: Color(0xFF8AB4FF),
    accentSoft: Color(0xFF22324D),
    success: Color(0xFF8ACDB8),
    successSoft: Color(0xFF20342D),
    warningSoft: Color(0xFF352D22),
  );

  @override
  AppColors copyWith({
    AppAccent? palette,
    Color? canvas,
    Color? surface,
    Color? inset,
    Color? ink,
    Color? muted,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? successSoft,
    Color? warningSoft,
  }) => AppColors(
    palette: palette ?? this.palette,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    inset: inset ?? this.inset,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warningSoft: warningSoft ?? this.warningSoft,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      palette: t < .5 ? palette : other.palette,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (isDark ? AppColors.dark : AppColors.light);
}

SystemUiOverlayStyle appSystemUiStyle(BuildContext context) =>
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: context.isDark
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: context.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: context.colors.canvas,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: context.isDark
          ? Brightness.light
          : Brightness.dark,
    );

// Menu items also receive focus on hover. Suppress that combined state,
// while retaining pressed/dragged feedback and keyboard focus without hover.
bool _hoverOnly(Set<WidgetState> states) =>
    states.contains(WidgetState.hovered) &&
    !states.contains(WidgetState.pressed) &&
    !states.contains(WidgetState.dragged);

final _noHoverOverlay = WidgetStateProperty.resolveWith<Color?>(
  (states) => _hoverOnly(states) ? Colors.transparent : null,
);

extension AppButtonHoverStyle on ButtonStyle {
  ButtonStyle withoutHover() => copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (states) => _hoverOnly(states)
          ? Colors.transparent
          : overlayColor?.resolve(states),
    ),
  );
}

final appTheme = _buildTheme(Brightness.light, AppAccent.blue);
final appDarkTheme = _buildTheme(Brightness.dark, AppAccent.blue);
final _warmTheme = _buildTheme(Brightness.light, AppAccent.warm);
final _warmDarkTheme = _buildTheme(Brightness.dark, AppAccent.warm);

extension AccentThemes on AppAccent {
  ThemeData get lightTheme => this == AppAccent.blue ? appTheme : _warmTheme;
  ThemeData get darkTheme =>
      this == AppAccent.blue ? appDarkTheme : _warmDarkTheme;
}

ThemeData _buildTheme(Brightness brightness, AppAccent palette) {
  final dark = brightness == Brightness.dark;
  final defaults = dark ? AppColors.dark : AppColors.light;
  final colors = palette == AppAccent.blue
      ? defaults
      : defaults.copyWith(
          palette: palette,
          accent: dark ? const Color(0xFFFFA2A6) : palette.seed,
          accentSoft: dark ? const Color(0xFF472932) : const Color(0xFFFFEFF0),
        );
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.seed,
        brightness: brightness,
        surface: colors.surface,
      ).copyWith(
        primary: colors.accent,
        onPrimary: dark
            ? (palette == AppAccent.warm
                  ? const Color(0xFF361722)
                  : const Color(0xFF102244))
            : Colors.white,
        onSurface: colors.ink,
        onSurfaceVariant: colors.muted,
        outline: colors.border,
      );
  return base.copyWith(
    extensions: [colors],
    hoverColor: Colors.transparent,
    tabBarTheme: TabBarThemeData(overlayColor: _noHoverOverlay),
    sliderTheme: SliderThemeData(
      overlayColor: WidgetStateColor.resolveWith((states) {
        if (_hoverOnly(states)) return Colors.transparent;
        if (states.contains(WidgetState.dragged) ||
            states.contains(WidgetState.focused)) {
          return scheme.primary.withValues(alpha: .1);
        }
        return Colors.transparent;
      }),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(overlayColor: _noHoverOverlay),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(overlayColor: _noHoverOverlay),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(overlayColor: _noHoverOverlay),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(overlayColor: _noHoverOverlay),
    ),
    checkboxTheme: CheckboxThemeData(overlayColor: _noHoverOverlay),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
      hoverElevation: 2,
      hoverColor: Colors.transparent,
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.surface,
    cardColor: colors.surface,
    dividerColor: colors.border,
    disabledColor: colors.muted.withValues(alpha: .5),
    iconTheme: IconThemeData(size: 24, color: colors.ink),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const AppIcon(AppIcons.back, size: 22),
      closeButtonIconBuilder: (_) => const AppIcon(AppIcons.close),
      drawerButtonIconBuilder: (_) => const AppIcon(AppIcons.menu),
      endDrawerButtonIconBuilder: (_) => const AppIcon(AppIcons.menu),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: colors.accent,
      scaffoldBackgroundColor: colors.canvas,
      barBackgroundColor: colors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: colors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: palette.seed,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ).withoutHover(),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ).withoutHover(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hoverColor: Colors.transparent,
      filled: true,
      fillColor: colors.inset,
      hintStyle: TextStyle(color: colors.muted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
    ),
    dialogTheme: DialogThemeData(backgroundColor: colors.surface),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
