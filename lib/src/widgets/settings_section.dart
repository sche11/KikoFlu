import 'package:flutter/material.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.child,
    this.color,
    this.margin,
    this.clipBehavior,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape;
    final side = BorderSide(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.16),
      width: 0.5,
    );

    return Card(
      color: color,
      margin: margin,
      clipBehavior: clipBehavior,
      shape: shape is RoundedRectangleBorder
          ? shape.copyWith(side: side)
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: side,
            ),
      child: child,
    );
  }
}

class SettingsSectionList extends StatelessWidget {
  const SettingsSectionList({
    super.key,
    required this.children,
    this.color,
    this.margin,
    this.clipBehavior,
  });

  final List<Widget> children;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      color: color,
      margin: margin,
      clipBehavior: clipBehavior,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SettingsDivider(),
            children[index],
          ],
        ],
      ),
    );
  }
}

class SettingsInfoCard extends StatelessWidget {
  const SettingsInfoCard({
    super.key,
    required this.icon,
    this.title,
    required this.child,
    this.color,
    this.margin,
    this.iconColor,
  });

  final IconData icon;
  final String? title;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedIconColor = iconColor ?? theme.colorScheme.primary;

    return SettingsSectionCard(
      color: color,
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: title == null
            ? Row(
                children: [
                  Icon(icon, color: resolvedIconColor),
                  const SizedBox(width: 12),
                  Expanded(child: child),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: resolvedIconColor),
                      const SizedBox(width: 8),
                      Text(
                        title!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.iconColor,
    this.iconSize,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedIconColor = iconColor ??
        (enabled ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return ListTile(
      enabled: enabled,
      leading: leading ?? Icon(icon, color: resolvedIconColor, size: iconSize),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: subtitleStyle ??
                  (enabled
                      ? null
                      : TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
      trailing: trailing,
      onTap: enabled ? onTap : null,
    );
  }
}

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.trailingIconSize,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final double? trailingIconSize;

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: trailingIconSize,
          ),
      onTap: onTap,
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    this.icon,
    this.secondary,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    required this.value,
    required this.onChanged,
    this.iconColor,
    this.enabled = true,
  }) : assert(icon != null || secondary != null);

  final IconData? icon;
  final Widget? secondary;
  final String title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      secondary:
          secondary ?? Icon(icon, color: iconColor ?? colorScheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!, style: subtitleStyle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({
    super.key,
    this.indent = 64,
    this.endIndent = 0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: indent,
      endIndent: endIndent,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}
