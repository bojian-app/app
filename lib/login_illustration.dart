import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_theme.dart';

/// “Happy Cat” by Vijay Verma; MIT license accompanies the SVG asset.
class LoginIllustration extends StatelessWidget {
  const LoginIllustration({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/login/happy-cat.svg',
      fit: BoxFit.contain,
      colorMapper: _LoginPalette(context.colors),
    ),
  );
}

class _LoginPalette extends ColorMapper {
  const _LoginPalette(this.colors);
  final AppColors colors;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    return switch (color.toARGB32()) {
      0xFF2359B2 => colors.accent,
      0xFF6DCCA3 => colors.success.withValues(alpha: .75),
      0xFF465172 || 0xFF1E2A54 => colors.ink,
      0xFFF78A21 => const Color(0xFFF6C98B),
      0xFFA83727 => const Color(0xFF705744),
      _ => color,
    };
  }
}
