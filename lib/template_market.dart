import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';
import 'network_image_cache.dart';

/// Thumbnail of a market template, shared by the template picker and the
/// membership page.
class MarketTemplateArtwork extends StatelessWidget {
  const MarketTemplateArtwork({
    super.key,
    required this.template,
    this.fit = BoxFit.contain,
  });
  final Map<String, dynamic> template;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final url = template['thumbnail_url'] as String? ?? '';
    final pending = template['preview_status'] == 'PENDING';
    final fallback = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.templatePreview,
              size: 28,
              color: context.colors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              pending ? '预览生成中' : '预览暂不可用',
              style: TextStyle(fontSize: 10, color: context.colors.muted),
            ),
          ],
        ),
      ),
    );
    return url.isEmpty
        ? fallback
        : Image(
            image: ResizeImage(CachedNetworkImage(url), width: 720),
            gaplessPlayback: true,
            fit: fit,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, _, _) => fallback,
          );
  }
}
