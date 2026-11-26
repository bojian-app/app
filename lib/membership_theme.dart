part of 'membership_page.dart';

/// 会员中心的表面、文字及选中状态跟随主题色与外观模式。
class _MembershipColors {
  const _MembershipColors({
    required this.background,
    required this.surface,
    required this.surfaceHi,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.selectedBorder,
    required this.unselectedBorder,
    required this.selectedPlan,
    required this.unselectedPlan,
    required this.selection,
    required this.benefitTint,
  });

  final Color background, surface, surfaceHi, line, text, muted;
  final Color accent, accentInk, selectedBorder, unselectedBorder;
  final Color selection, benefitTint;
  final List<Color> selectedPlan, unselectedPlan;

  static _MembershipColors of(BuildContext context) =>
      switch ((context.colors.palette, context.isDark)) {
        (AppAccent.blue, false) => light,
        (AppAccent.blue, true) => dark,
        (AppAccent.warm, false) => warmLight,
        (AppAccent.warm, true) => warmDark,
        (AppAccent.green, false) => greenLight,
        (AppAccent.green, true) => greenDark,
      };

  static const light = _MembershipColors(
    background: Colors.white,
    surface: Color(0xFFF7FAFF),
    surfaceHi: Color(0xFFEAF2FC),
    line: Color(0xFFDCE6F3),
    text: Color(0xFF223047),
    muted: Color(0xFF5C6E86),
    accent: Color(0xFF275FBA),
    accentInk: Colors.white,
    selectedBorder: Color(0xFF7098FF),
    unselectedBorder: Color(0xFFDCE6F3),
    selectedPlan: [Color(0xFFF5F9FF), Color(0xFFE4EDFF)],
    unselectedPlan: [Colors.white, Color(0xFFF7FAFF)],
    selection: Color(0xFF246BFF),
    benefitTint: Color(0xFFEAF3FF),
  );

  static const dark = _MembershipColors(
    background: _bg,
    surface: _surface,
    surfaceHi: _surfaceHi,
    line: _line,
    text: _text,
    muted: _muted,
    accent: _platinum,
    accentInk: _platinumInk,
    selectedBorder: Color(0xFF8DAED7),
    unselectedBorder: Color(0xFF354354),
    selectedPlan: [Color(0xFF2B3C54), Color(0xFF1D2C40)],
    unselectedPlan: [Color(0xFF1D2938), Color(0xFF161F2C)],
    selection: Color(0xFF83B2FF),
    benefitTint: Color(0x1FA3C7F3),
  );

  static const warmLight = _MembershipColors(
    background: Colors.white,
    surface: Color(0xFFFFFAF8),
    surfaceHi: Color(0xFFFBECE8),
    line: Color(0xFFEEDFDA),
    text: Color(0xFF402D30),
    muted: Color(0xFF795E60),
    accent: Color(0xFFAF4151),
    accentInk: Colors.white,
    selectedBorder: Color(0xFFDB826F),
    unselectedBorder: Color(0xFFEBDEDA),
    selectedPlan: [Color(0xFFFFF8F5), Color(0xFFFBE5DD)],
    unselectedPlan: [Colors.white, Color(0xFFFFFAF8)],
    selection: Color(0xFFC64350),
    benefitTint: Color(0xFFFFEFEB),
  );

  static const warmDark = _MembershipColors(
    background: Color(0xFF1D1518),
    surface: Color(0xFF2B2023),
    surfaceHi: Color(0xFF403033),
    line: Color(0x29F6CFBD),
    text: Color(0xFFFFF3EF),
    muted: Color(0xFFCAAFAA),
    accent: Color(0xFFF9D5C4),
    accentInk: Color(0xFF49292D),
    selectedBorder: Color(0xFFDC9F92),
    unselectedBorder: Color(0xFF544043),
    selectedPlan: [Color(0xFF51343C), Color(0xFF39262B)],
    unselectedPlan: [Color(0xFF33262A), Color(0xFF251C20)],
    selection: Color(0xFFFFA2A6),
    benefitTint: Color(0x22F4B5A5),
  );

  static const greenLight = _MembershipColors(
    background: Colors.white,
    surface: Color(0xFFF7FCF9),
    surfaceHi: Color(0xFFE6F4EC),
    line: Color(0xFFD6E8DD),
    text: Color(0xFF1F3A2D),
    muted: Color(0xFF56705F),
    accent: Color(0xFF1A7A4E),
    accentInk: Colors.white,
    selectedBorder: Color(0xFF5FBF8F),
    unselectedBorder: Color(0xFFD9E8DF),
    selectedPlan: [Color(0xFFF5FCF8), Color(0xFFDDF1E6)],
    unselectedPlan: [Colors.white, Color(0xFFF7FCF9)],
    selection: Color(0xFF1D8A5A),
    benefitTint: Color(0xFFE9F6EF),
  );

  static const greenDark = _MembershipColors(
    background: Color(0xFF121A16),
    surface: Color(0xFF1B2620),
    surfaceHi: Color(0xFF2A3830),
    line: Color(0x29BFE8D2),
    text: Color(0xFFEAF7F0),
    muted: Color(0xFFA9C3B3),
    accent: Color(0xFFCDEBD9),
    accentInk: Color(0xFF173A28),
    selectedBorder: Color(0xFF7FB898),
    unselectedBorder: Color(0xFF334239),
    selectedPlan: [Color(0xFF2D4A3B), Color(0xFF21362B)],
    unselectedPlan: [Color(0xFF1F2E26), Color(0xFF17221C)],
    selection: Color(0xFF7FD8AE),
    benefitTint: Color(0x227FD8AE),
  );
}

/// The metal face and its embossing stay dark in both display modes.
extension _MembershipFinish on AppAccent {
  List<Color> get metalFace => switch (this) {
    AppAccent.warm => const [
      Color(0xFF775159),
      Color(0xFF50323A),
      Color(0xFF352127),
      Color(0xFF4B3036),
    ],
    AppAccent.green => const [
      Color(0xFF3F6B55),
      Color(0xFF264636),
      Color(0xFF182C21),
      Color(0xFF22382B),
    ],
    AppAccent.blue => const [
      Color(0xFF3A4D68),
      Color(0xFF233249),
      Color(0xFF162234),
      Color(0xFF1E2D42),
    ],
  };
  Color get metalInk => switch (this) {
    AppAccent.warm => const Color(0xFF42282C),
    AppAccent.green => const Color(0xFF1E3A2A),
    AppAccent.blue => _platinumInk,
  };
  Color get engraving => switch (this) {
    AppAccent.warm => const Color(0xFFF8EAE4),
    AppAccent.green => const Color(0xFFE6F4EC),
    AppAccent.blue => const Color(0xFFE4ECF7),
  };
  Color get secondaryEngraving => switch (this) {
    AppAccent.warm => const Color(0xFFDDC2B9),
    AppAccent.green => const Color(0xFFB9D6C4),
    AppAccent.blue => const Color(0xFFB9CAE0),
  };
  LinearGradient get crystalGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: switch (this) {
      AppAccent.warm => const [
        Color(0xFFFFF7EE),
        Color(0xFFF2CEBD),
        Color(0xFFD7A295),
      ],
      AppAccent.green => const [
        Color(0xFFF3FFF8),
        Color(0xFFC9EBD7),
        Color(0xFF8FC7A6),
      ],
      AppAccent.blue => _crystal,
    },
  );
  LinearGradient get purchaseGradient => LinearGradient(
    colors: switch (this) {
      AppAccent.warm => const [Color(0xFFD86654), Color(0xFFB72E4C)],
      AppAccent.green => const [Color(0xFF2FB27A), Color(0xFF157A4F)],
      AppAccent.blue => _blueGradient,
    },
  );
}
