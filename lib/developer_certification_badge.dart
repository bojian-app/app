import 'package:flutter/material.dart';

/// A compact crystal credential. Its identity is announced without a visible label.
class DeveloperCertificationBadge extends StatelessWidget {
  const DeveloperCertificationBadge({super.key, this.size = expandedSize});
  static const expandedSize = 26 * 2 / 3;
  static const compactSize = 18 * 2 / 3;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '开发者认证，已通过',
    image: true,
    child: Tooltip(
      message: '开发者认证',
      excludeFromSemantics: true,
      child: Image.asset(
        'assets/badges/developer_crystal_v1.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: 192,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    ),
  );
}
