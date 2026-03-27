import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/snackbar_util.dart';
import '../widgets/scrollable_appbar.dart';

/// 防社死设置页面
class PrivacyModeSettingsScreen extends ConsumerStatefulWidget {
  const PrivacyModeSettingsScreen({super.key});

  @override
  ConsumerState<PrivacyModeSettingsScreen> createState() =>
      _PrivacyModeSettingsScreenState();
}

class _PrivacyModeSettingsScreenState
    extends ConsumerState<PrivacyModeSettingsScreen> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 延迟加载，确保 ref 可用
    Future.microtask(() {
      if (mounted) {
        final settings = ref.read(privacyModeSettingsProvider);
        _titleController.text = settings.customTitle;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showEditTitleDialog() {
    final settings = ref.read(privacyModeSettingsProvider);
    _titleController.text = settings.customTitle;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).setReplaceTitle),
        content: TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: S.of(context).replaceTitle,
            hintText: S.of(context).enterDisplayTitle,
            border: const OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel),
          ),
          FilledButton(
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isNotEmpty) {
                ref
                    .read(privacyModeSettingsProvider.notifier)
                    .setCustomTitle(title);
                Navigator.pop(context);
                SnackBarUtil.showSuccess(context, S.of(context).replaceTitleSaved);
              }
            },
            child: Text(S.of(context).save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(privacyModeSettingsProvider);

    return Scaffold(
      appBar: ScrollableAppBar(
        title: Text(S.of(context).privacyModeSettingsTitle, style: const TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).whatIsPrivacyMode,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.of(context).privacyModeDescription,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 主开关
          Card(
            child: SwitchListTile(
              secondary: Icon(
                settings.enabled ? Icons.shield : Icons.shield_outlined,
                color: settings.enabled
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(S.of(context).enablePrivacyMode),
              subtitle: Text(
                settings.enabled ? S.of(context).privacyModeEnabledSubtitle : S.of(context).privacyModeDisabledSubtitle,
              ),
              value: settings.enabled,
              onChanged: (value) {
                ref
                    .read(privacyModeSettingsProvider.notifier)
                    .setEnabled(value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // 详细设置
          Card(
            child: Column(
              children: [
                // 标题说明
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).blurOptions,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),

                // 通知封面模糊
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).blurNotificationCover),
                  subtitle: Text(S.of(context).blurNotificationCoverSubtitle),
                  value: settings.blurCover,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(privacyModeSettingsProvider.notifier)
                              .setBlurCover(value);
                        }
                      : null,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),

                // 应用内封面模糊
                SwitchListTile(
                  secondary: Icon(
                    Icons.blur_on,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).blurInAppCover),
                  subtitle: Text(S.of(context).blurInAppCoverSubtitle),
                  value: settings.blurCoverInApp,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(privacyModeSettingsProvider.notifier)
                              .setBlurCoverInApp(value);
                        }
                      : null,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),

                // 标题替换
                SwitchListTile(
                  secondary: Icon(
                    Icons.text_fields,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).replaceTitle),
                  subtitle: Text(S.of(context).replaceTitleSubtitle),
                  value: settings.maskTitle,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(privacyModeSettingsProvider.notifier)
                              .setMaskTitle(value);
                        }
                      : null,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),

                // 自定义标题
                ListTile(
                  enabled: settings.enabled && settings.maskTitle,
                  leading: Icon(
                    Icons.edit,
                    color: settings.enabled && settings.maskTitle
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(S.of(context).replaceTitleContent),
                  subtitle: Text(settings.customTitle),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: settings.enabled && settings.maskTitle
                      ? _showEditTitleDialog
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 效果举例
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.preview,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).effectExample,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/privacy_protection_sample.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
