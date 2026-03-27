import 'package:flutter/material.dart';
import '../models/work.dart';
import '../screens/search_result_screen.dart';
import '../../l10n/app_localizations.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final FontWeight? fontWeight;

  const TagChip({
    super.key,
    required this.tag,
    this.onDeleted,
    this.onTap,
    this.onLongPress,
    this.compact = false,
    this.fontSize,
    this.padding,
    this.borderRadius,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    // 如果提供了自定义样式参数，使用自定义样式
    if (fontSize != null || padding != null || borderRadius != null) {
      return GestureDetector(
        onTap: onTap ??
            () {
              print('[TagChip] Clicked tag: ${tag.name}, id: ${tag.id}');
              // 默认跳转到标签搜索结果页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultScreen(
                    keyword: tag.name,
                    searchTypeLabel: S.of(context).searchTypeTag,
                    searchParams: {'tagId': tag.id, 'tagName': tag.name},
                  ),
                ),
              );
            },
        onLongPress: onLongPress,
        child: Container(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(borderRadius ?? 12),
          ),
          child: Text(
            tag.name,
            style: TextStyle(
              fontSize: fontSize ?? 11,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: fontWeight ?? FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // 使用默认的 Chip 样式
    if (onDeleted != null) {
      // 如果有删除功能，使用 InputChip
      return InputChip(
        label: Text(tag.name),
        onPressed: onTap ??
            () {
              print('[TagChip] Clicked tag: ${tag.name}, id: ${tag.id}');
              // 默认跳转到标签搜索结果页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultScreen(
                    keyword: tag.name,
                    searchTypeLabel: S.of(context).searchTypeTag,
                    searchParams: {'tagId': tag.id, 'tagName': tag.name},
                  ),
                ),
              );
            },
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 18),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          fontSize: compact ? 10 : null,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 0)
            : null,
        visualDensity: compact ? VisualDensity.compact : null,
      );
    } else {
      // 如果没有删除功能，使用 ActionChip
      return ActionChip(
        label: Text(tag.name),
        onPressed: onTap ??
            () {
              print('[TagChip] Clicked tag: ${tag.name}, id: ${tag.id}');
              // 默认跳转到标签搜索结果页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultScreen(
                    keyword: tag.name,
                    searchTypeLabel: S.of(context).searchTypeTag,
                    searchParams: {'tagId': tag.id, 'tagName': tag.name},
                  ),
                ),
              );
            },
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          fontSize: compact ? 10 : null,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 0)
            : null,
        visualDensity: compact ? VisualDensity.compact : null,
      );
    }
  }
}
