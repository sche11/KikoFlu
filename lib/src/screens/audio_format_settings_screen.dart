import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../widgets/scrollable_appbar.dart';

class AudioFormatSettingsScreen extends ConsumerStatefulWidget {
  const AudioFormatSettingsScreen({super.key});

  @override
  ConsumerState<AudioFormatSettingsScreen> createState() =>
      _AudioFormatSettingsScreenState();
}

class _AudioFormatSettingsScreenState
    extends ConsumerState<AudioFormatSettingsScreen> {
  late List<AudioFormat> _formatOrder;

  @override
  void initState() {
    super.initState();
    // 延迟初始化以确保provider已经加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preference = ref.read(audioFormatPreferenceProvider);
      setState(() {
        _formatOrder = List.from(preference.priority);
      });
    });
  }

  Future<void> _saveSettings() async {
    await ref
        .read(audioFormatPreferenceProvider.notifier)
        .updatePriority(_formatOrder);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).settingsSaved)),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).restoreDefaultSettings),
        content: Text(S.of(context).confirmRestoreAudioFormat),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.of(context).confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(audioFormatPreferenceProvider.notifier).resetToDefault();
      final preference = ref.read(audioFormatPreferenceProvider);
      setState(() {
        _formatOrder = List.from(preference.priority);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).restoredToDefault)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScrollableAppBar(
        title: Text(S.of(context).audioFormatPriority, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.restart_alt),
            label: Text(S.of(context).restoreDefault),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _formatOrder.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 说明卡片
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).priorityDescription,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          S.of(context).audioFormatPriorityDesc,
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                // 格式列表
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _formatOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = _formatOrder.removeAt(oldIndex);
                        _formatOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final format = _formatOrder[index];
                      return Card(
                        key: ValueKey(format),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            format.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '.${format.extension}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_handle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 保存按钮
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.check),
                        label: Text(S.of(context).saveSettings),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
