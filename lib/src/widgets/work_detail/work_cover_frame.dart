import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../privacy_blur_cover.dart';

class WorkCoverFrame extends StatelessWidget {
  const WorkCoverFrame({
    super.key,
    required this.heroTag,
    required this.isLandscape,
    required this.layers,
    this.showSubtitleBadge = false,
    this.onLongPress,
  });

  final Object heroTag;
  final bool isLandscape;
  final List<Widget> layers;
  final bool showSubtitleBadge;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: isLandscape ? null : double.infinity,
              constraints: BoxConstraints(
                maxHeight: isLandscape ? mediaSize.height * 0.8 : 500,
                maxWidth:
                    isLandscape ? mediaSize.width * 0.45 : double.infinity,
              ),
              child: PrivacyBlurCover(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    ...layers,
                    if (showSubtitleBadge) const _SubtitleBadge(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleBadge extends StatelessWidget {
  const _SubtitleBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          S.of(context).subtitleBadge,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
