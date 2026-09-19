import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import 'main_navigation_items.dart';

class MainNavigationRail extends StatelessWidget {
  const MainNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.liquidGlass = false,
    this.fallbackGlassTransparency = 0.4,
    this.showUpdateBadge = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final bool liquidGlass;
  final double fallbackGlassTransparency;
  final bool showUpdateBadge;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildRail(context, constraints.maxHeight),
  );

  Widget _buildRail(BuildContext context, double viewportHeight) {
    if (liquidGlass &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        LiquidGlass.cachedCapabilities?.nativeGlass == true) {
      final theme = Theme.of(context);
      final media = MediaQuery.of(context);
      // Use the actual body constraints, including keyboard and safe-area
      // insets. UIKit owns scrolling inside this finite native viewport.
      return SizedBox(
        width: 96,
        height: viewportHeight.clamp(0.0, double.infinity),
        child: NativeGlassNavigationRail(
          items: mainNavigationGlassItems(destinations),
          currentIndex: selectedIndex,
          onChanged: onDestinationSelected,
          selectedColor: theme.colorScheme.onPrimaryContainer,
          selectedBackgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          fontSize: media.textScaler.scale(
            theme.textTheme.labelMedium?.fontSize ?? 12,
          ),
          badgeIndex: showUpdateBadge ? destinations.length - 1 : null,
          badgeColor: theme.colorScheme.error,
        ),
      );
    }

    final rail = NavigationRail(
      backgroundColor: liquidGlass ? Colors.transparent : null,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: Text(destination.label),
          ),
      ],
    );
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportHeight),
        child: IntrinsicHeight(
          child: liquidGlass
              ? LiquidGlassContainer(
                  shape: const LiquidGlassShape.roundedRectangle(28),
                  fallbackIntensity: fallbackGlassTransparency,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: rail,
                  ),
                )
              : rail,
        ),
      ),
    );
  }
}
