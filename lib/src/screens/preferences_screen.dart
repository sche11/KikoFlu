import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'audio_format_settings_screen.dart';
import 'blocked_items_screen.dart';
import 'llm_settings_screen.dart';
import '../models/sort_options.dart';
import '../providers/settings_provider.dart';
import '../utils/l10n_extensions.dart';
import '../utils/snackbar_util.dart';
import '../widgets/radio_option_group.dart';
import '../widgets/scrollable_appbar.dart';
import '../widgets/sort_dialog.dart';

/// 偏好设置页面
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  void _showSubtitleLibraryPriorityDialog(
      BuildContext pageContext, WidgetRef ref) {
    final currentPriority = ref.read(subtitleLibraryPriorityProvider);

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          S.of(dialogContext).subtitleLibraryPriority,
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(dialogContext).selectSubtitlePriority,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            RadioOptionGroup<SubtitleLibraryPriority>(
              groupValue: currentPriority,
              options: [
                for (final priority in SubtitleLibraryPriority.values)
                  RadioOption(
                    value: priority,
                    title: Text(priority.localizedName(dialogContext)),
                    subtitle: Text(
                      priority == SubtitleLibraryPriority.highest
                          ? S.of(dialogContext).subtitlePriorityHighestDesc
                          : S.of(dialogContext).subtitlePriorityLowestDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                ref
                    .read(subtitleLibraryPriorityProvider.notifier)
                    .updatePriority(value);
                Navigator.pop(dialogContext);
                SnackBarUtil.showSuccess(
                  pageContext,
                  S
                      .of(pageContext)
                      .setToValue(value.localizedName(pageContext)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(dialogContext).close),
          ),
        ],
      ),
    );
  }

  void _showDefaultSortDialog(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(defaultSortProvider);

    showDialog(
      context: context,
      builder: (context) => CommonSortDialog(
        title: S.of(context).defaultSortSettings,
        currentOption: currentSort.order,
        currentDirection: currentSort.direction,
        availableOptions: SortOrder.values
            .where((option) => option != SortOrder.updatedAt)
            .toList(),
        onSort: (option, direction) {
          ref
              .read(defaultSortProvider.notifier)
              .updateDefaultSort(option, direction);
          SnackBarUtil.showSuccess(
            context,
            S.of(context).defaultSortUpdated,
          );
        },
        autoClose: false,
      ),
    );
  }

  void _showTranslationSourceDialog(BuildContext pageContext, WidgetRef ref) {
    final currentSource = ref.read(translationSourceProvider);

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          S.of(dialogContext).translationSourceSettings,
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(dialogContext).selectTranslationProvider,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            RadioOptionGroup<TranslationSource>(
              groupValue: currentSource,
              options: [
                for (final source in TranslationSource.values)
                  RadioOption(
                    value: source,
                    title: Text(source.localizedName(dialogContext)),
                    subtitle: Text(
                      _getTranslationSourceDescription(dialogContext, source),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == TranslationSource.llm) {
                  final llmSettings = ref.read(llmSettingsProvider);
                  if (llmSettings.apiKey.isEmpty) {
                    showDialog(
                      context: dialogContext,
                      builder: (configContext) => AlertDialog(
                        title: Text(S.of(configContext).needsConfiguration),
                        content:
                            Text(S.of(configContext).llmConfigRequiredMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(configContext),
                            child: Text(S.of(configContext).cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              final navigator = Navigator.of(configContext);
                              navigator.pop(); // Close alert dialog
                              navigator.pop(); // Close source selection dialog
                              await navigator.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LLMSettingsScreen(),
                                ),
                              );

                              // Check if configured successfully
                              final newSettings = ref.read(llmSettingsProvider);
                              if (newSettings.apiKey.isNotEmpty) {
                                ref
                                    .read(translationSourceProvider.notifier)
                                    .updateSource(TranslationSource.llm);
                                if (pageContext.mounted) {
                                  SnackBarUtil.showSuccess(
                                    pageContext,
                                    S.of(pageContext).autoSwitchedToLlm,
                                  );
                                }
                              }
                            },
                            child: Text(S.of(configContext).goToConfigure),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                }

                ref
                    .read(translationSourceProvider.notifier)
                    .updateSource(value);
                Navigator.pop(dialogContext);
                SnackBarUtil.showSuccess(
                  pageContext,
                  S
                      .of(pageContext)
                      .setToValue(value.localizedName(pageContext)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(dialogContext).close),
          ),
        ],
      ),
    );
  }

  void _showTranslationSourceLanguageDialog(
      BuildContext pageContext, WidgetRef ref) {
    final translationSource = ref.read(translationSourceProvider);
    final preferences = ref.read(translationLanguagePreferencesProvider);
    final currentLanguage = preferences.sourceLanguage;
    final options = TranslationSourceLanguage.values.where((language) {
      return translationSource == TranslationSource.llm ||
          language != TranslationSourceLanguage.custom;
    }).toList();

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          S.of(dialogContext).translationSourceLanguage,
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(dialogContext).selectTranslationSourceLanguage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            RadioOptionGroup<TranslationSourceLanguage>(
              groupValue: options.contains(currentLanguage)
                  ? currentLanguage
                  : TranslationSourceLanguage.automatic,
              options: [
                for (final language in options)
                  RadioOption(
                    value: language,
                    title: Text(_languageOptionLabel(
                      dialogContext,
                      language.localizedName(dialogContext),
                      language == TranslationSourceLanguage.custom
                          ? preferences.customSourceLanguage
                          : null,
                    )),
                  ),
              ],
              onChanged: (value) async {
                if (value == TranslationSourceLanguage.custom) {
                  final customLanguage = await _showCustomLanguageDialog(
                    pageContext,
                    title: S.of(pageContext).translationCustomSourceLanguage,
                    initialValue: preferences.customSourceLanguage,
                  );
                  if (customLanguage == null) return;
                  await ref
                      .read(translationLanguagePreferencesProvider.notifier)
                      .updateCustomSourceLanguage(customLanguage);
                }

                await ref
                    .read(translationLanguagePreferencesProvider.notifier)
                    .updateSourceLanguage(value);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                SnackBarUtil.showSuccess(
                  pageContext,
                  S
                      .of(pageContext)
                      .setToValue(value.localizedName(pageContext)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(dialogContext).close),
          ),
        ],
      ),
    );
  }

  void _showTranslationTargetLanguageDialog(
      BuildContext pageContext, WidgetRef ref) {
    final translationSource = ref.read(translationSourceProvider);
    final preferences = ref.read(translationLanguagePreferencesProvider);
    final currentLanguage = preferences.targetLanguage;
    final options = TranslationTargetLanguage.values.where((language) {
      return translationSource == TranslationSource.llm ||
          language != TranslationTargetLanguage.custom;
    }).toList();

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          S.of(dialogContext).translationTargetLanguage,
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(dialogContext).selectTranslationTargetLanguage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            RadioOptionGroup<TranslationTargetLanguage>(
              groupValue: options.contains(currentLanguage)
                  ? currentLanguage
                  : TranslationTargetLanguage.followApp,
              options: [
                for (final language in options)
                  RadioOption(
                    value: language,
                    title: Text(_languageOptionLabel(
                      dialogContext,
                      language.localizedName(dialogContext),
                      language == TranslationTargetLanguage.custom
                          ? preferences.customTargetLanguage
                          : null,
                    )),
                  ),
              ],
              onChanged: (value) async {
                if (value == TranslationTargetLanguage.custom) {
                  final customLanguage = await _showCustomLanguageDialog(
                    pageContext,
                    title: S.of(pageContext).translationCustomTargetLanguage,
                    initialValue: preferences.customTargetLanguage,
                  );
                  if (customLanguage == null) return;
                  await ref
                      .read(translationLanguagePreferencesProvider.notifier)
                      .updateCustomTargetLanguage(customLanguage);
                }

                await ref
                    .read(translationLanguagePreferencesProvider.notifier)
                    .updateTargetLanguage(value);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                SnackBarUtil.showSuccess(
                  pageContext,
                  S
                      .of(pageContext)
                      .setToValue(value.localizedName(pageContext)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(dialogContext).close),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCustomLanguageDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: S.of(dialogContext).translationCustomLanguageHint,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.pop(dialogContext, text);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(dialogContext).cancel),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogContext, text);
              }
            },
            child: Text(S.of(dialogContext).confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _languageOptionLabel(
    BuildContext context,
    String label,
    String? customValue,
  ) {
    final trimmedValue = customValue?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return label;
    }
    return S.of(context).translationCustomLanguageLabel(trimmedValue);
  }

  String _sourceLanguageLabel(
    BuildContext context,
    TranslationLanguagePreferences preferences,
  ) {
    if (preferences.sourceLanguage == TranslationSourceLanguage.custom &&
        preferences.customSourceLanguage.isNotEmpty) {
      return S
          .of(context)
          .translationCustomLanguageLabel(preferences.customSourceLanguage);
    }
    return preferences.sourceLanguage.localizedName(context);
  }

  String _targetLanguageLabel(
    BuildContext context,
    TranslationLanguagePreferences preferences,
  ) {
    if (preferences.targetLanguage == TranslationTargetLanguage.custom &&
        preferences.customTargetLanguage.isNotEmpty) {
      return S
          .of(context)
          .translationCustomLanguageLabel(preferences.customTargetLanguage);
    }
    return preferences.targetLanguage.localizedName(context);
  }

  String _getTranslationSourceDescription(
      BuildContext context, TranslationSource source) {
    final s = S.of(context);
    switch (source) {
      case TranslationSource.google:
        return s.translationDescGoogle;
      case TranslationSource.youdao:
        return s.translationDescYoudao;
      case TranslationSource.microsoft:
        return s.translationDescMicrosoft;
      case TranslationSource.llm:
        return s.translationDescLlm;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = ref.watch(subtitleLibraryPriorityProvider);
    final defaultSort = ref.watch(defaultSortProvider);
    final translationSource = ref.watch(translationSourceProvider);
    final translationLanguagePreferences =
        ref.watch(translationLanguagePreferencesProvider);

    return Scaffold(
      appBar: ScrollableAppBar(
        title: Text(S.of(context).preferenceSettings,
            style: const TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.library_books,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).subtitleLibraryPriority),
                  subtitle: Text(S
                      .of(context)
                      .currentSettingLabel(priority.localizedName(context))),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showSubtitleLibraryPriorityDialog(context, ref);
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.sort,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).defaultSortSettingTitle),
                  subtitle: Text(
                      '${defaultSort.order.localizedLabel(context)} - ${defaultSort.direction.localizedLabel(context)}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showDefaultSortDialog(context, ref);
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.translate,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).translationSource),
                  subtitle: Text(S.of(context).currentSettingLabel(
                      translationSource.localizedName(context))),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showTranslationSourceDialog(context, ref);
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.input,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).translationSourceLanguage),
                  subtitle: Text(S.of(context).currentSettingLabel(
                      _sourceLanguageLabel(
                          context, translationLanguagePreferences))),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showTranslationSourceLanguageDialog(context, ref);
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.language,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).translationTargetLanguage),
                  subtitle: Text(S.of(context).currentSettingLabel(
                      _targetLanguageLabel(
                          context, translationLanguagePreferences))),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showTranslationTargetLanguageDialog(context, ref);
                  },
                ),
                if (translationSource == TranslationSource.llm) ...[
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
                  ListTile(
                    leading: Icon(Icons.settings_input_component,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(S.of(context).llmSettings),
                    subtitle: Text(S.of(context).llmSettingsSubtitle),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LLMSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.audio_file,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).audioFormatPreference),
                  subtitle: Text(S.of(context).audioFormatSubtitle),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AudioFormatSettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(Icons.screen_lock_portrait,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).keepScreenAwake),
                  subtitle: Text(
                    S.of(context).keepScreenAwakeDesc,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: ref.watch(keepScreenAwakeProvider),
                  onChanged: (value) {
                    ref
                        .read(keepScreenAwakeProvider.notifier)
                        .setEnabled(value);
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.block,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(S.of(context).blockingSettings),
                  subtitle: Text(S.of(context).blockingSettingsSubtitle),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BlockedItemsScreen(),
                      ),
                    );
                  },
                ),
                // 仅在 Android, Windows 和 macOS 平台上显示音频直通设置
                if (Theme.of(context).platform == TargetPlatform.android ||
                    Theme.of(context).platform == TargetPlatform.windows ||
                    Theme.of(context).platform == TargetPlatform.macOS) ...[
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
                  SwitchListTile(
                    secondary: Icon(Icons.surround_sound,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(S.of(context).audioPassthrough),
                    subtitle: Text(
                      (Theme.of(context).platform == TargetPlatform.windows ||
                              Theme.of(context).platform ==
                                  TargetPlatform.macOS)
                          ? S.of(context).audioPassthroughDescWindows
                          : S.of(context).audioPassthroughDescAndroid,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: ref.watch(audioPassthroughProvider),
                    onChanged: (value) async {
                      if (value) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(S.of(context).warning),
                            content:
                                Text(S.of(context).audioPassthroughWarning),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(S.of(context).cancel),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(S.of(context).confirm),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;
                      }

                      ref.read(audioPassthroughProvider.notifier).toggle(value);
                      if (context.mounted) {
                        SnackBarUtil.showSuccess(
                          context,
                          value
                              ? ((Theme.of(context).platform ==
                                          TargetPlatform.windows ||
                                      Theme.of(context).platform ==
                                          TargetPlatform.macOS)
                                  ? S.of(context).exclusiveModeEnabled
                                  : S.of(context).audioPassthroughEnabled)
                              : S.of(context).audioPassthroughDisabled,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
