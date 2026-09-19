import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

/// Keep native bottom and side navigation icons in sync across rotation.
List<LiquidGlassBarItem> mainNavigationGlassItems(
  List<NavigationDestination> destinations,
) {
  const icons = [
    (Icons.home_outlined, Icons.home, 'house', 'house.fill'),
    (Icons.search_outlined, Icons.search, 'magnifyingglass', 'magnifyingglass'),
    (Icons.favorite_border, Icons.favorite, 'heart', 'heart.fill'),
    (Icons.settings_outlined, Icons.settings, 'gearshape', 'gearshape.fill'),
  ];
  return [
    for (var index = 0; index < destinations.length; index++)
      LiquidGlassBarItem(
        icon: index < icons.length ? icons[index].$1 : Icons.circle_outlined,
        selectedIcon: index < icons.length ? icons[index].$2 : Icons.circle,
        sfSymbol: index < icons.length ? icons[index].$3 : 'circle',
        selectedSfSymbol: index < icons.length
            ? icons[index].$4
            : 'circle.fill',
        label: destinations[index].label,
      ),
  ];
}
