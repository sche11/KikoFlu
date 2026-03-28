import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/work_detail_display_provider.dart';
import '../widgets/scrollable_appbar.dart';

class WorkDetailDisplaySettingsScreen extends ConsumerWidget {
  const WorkDetailDisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(workDetailDisplayProvider);
    final notifier = ref.read(workDetailDisplayProvider.notifier);

    return Scaffold(
      appBar: ScrollableAppBar(
        title: Text(
          S.of(context).workDetailDisplaySettings,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).ratingInfo),
                  subtitle: Text(S.of(context).showRatingAndReviewCount),
                  value: settings.showRating,
                  onChanged: (_) => notifier.toggleRating(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.attach_money,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).priceInfo),
                  subtitle: Text(S.of(context).showWorkPrice),
                  value: settings.showPrice,
                  onChanged: (_) => notifier.togglePrice(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).durationInfo),
                  subtitle: Text(S.of(context).showWorkDuration),
                  value: settings.showDuration,
                  onChanged: (_) => notifier.toggleDuration(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.shopping_cart,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).salesInfo),
                  subtitle: Text(S.of(context).showWorkSalesCount),
                  value: settings.showSales,
                  onChanged: (_) => notifier.toggleSales(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.open_in_new,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).externalLinkInfo),
                  subtitle: Text(S.of(context).showExternalLinks),
                  value: settings.showExternalLinks,
                  onChanged: (_) => notifier.toggleExternalLinks(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).releaseDateInfo),
                  subtitle: Text(S.of(context).showWorkReleaseDate),
                  value: settings.showReleaseDate,
                  onChanged: (_) => notifier.toggleReleaseDate(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.translate,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).translateButtonLabel),
                  subtitle: Text(S.of(context).showTranslateButton),
                  value: settings.showTranslateButton,
                  onChanged: (_) => notifier.toggleTranslateButton(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.closed_caption,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).subtitleTagLabel),
                  subtitle: Text(S.of(context).showSubtitleTagOnCover),
                  value: settings.showSubtitleTag,
                  onChanged: (_) => notifier.toggleSubtitleTag(),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(
                    Icons.recommend_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(S.of(context).recommendationsLabel),
                  subtitle: Text(S.of(context).showRecommendations),
                  value: settings.showRecommendations,
                  onChanged: (_) => notifier.toggleRecommendations(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
