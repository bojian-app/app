part of 'membership_page.dart';

/// 会员页随应用主题切换，独立于确认订单页的蓝色操作样式。
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
    required this.card,
  });

  final Color background, surface, surfaceHi, line, text, muted;
  final Color accent, accentInk, selectedBorder, unselectedBorder;
  final List<Color> selectedPlan, unselectedPlan, card;

  static _MembershipColors of(BuildContext context) =>
      context.isDark ? dark : light;

  static const light = _MembershipColors(
    background: Colors.white,
    surface: Color(0xFFF7FAFF),
    surfaceHi: Color(0xFFEAF2FC),
    line: Color(0xFFDCE6F3),
    text: Color(0xFF223047),
    muted: Color(0xFF5C6E86),
    accent: Color(0xFF275FBA),
    accentInk: Colors.white,
    selectedBorder: Color(0xFF8EB0DF),
    unselectedBorder: Color(0xFFDCE6F3),
    selectedPlan: [Color(0xFFEFF6FF), Color(0xFFE0EDFC)],
    unselectedPlan: [Colors.white, Color(0xFFF7FAFF)],
    card: [Color(0xFFF9FCFF), Color(0xFFE5EEF9), Color(0xFFCDDFF1)],
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
    card: [Color(0xFF304158), Color(0xFF202F43), Color(0xFF141F2E)],
  );
}
