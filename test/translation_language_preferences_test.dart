import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpAsyncPreferenceLoad() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('translation language preferences default to auto and app language',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var preferences = container.read(translationLanguagePreferencesProvider);
    expect(preferences.sourceLanguage, TranslationSourceLanguage.automatic);
    expect(preferences.targetLanguage, TranslationTargetLanguage.followApp);

    await _pumpAsyncPreferenceLoad();

    preferences = container.read(translationLanguagePreferencesProvider);
    expect(preferences.sourceLanguage, TranslationSourceLanguage.automatic);
    expect(preferences.targetLanguage, TranslationTargetLanguage.followApp);
  });

  test('translation language preferences load and persist custom values',
      () async {
    SharedPreferences.setMockInitialValues({
      TranslationLanguagePreferencesNotifier.keySourceLanguage:
          TranslationSourceLanguage.japanese.value,
      TranslationLanguagePreferencesNotifier.keyTargetLanguage:
          TranslationTargetLanguage.english.value,
      TranslationLanguagePreferencesNotifier.keyCustomSourceLanguage: 'Korean',
      TranslationLanguagePreferencesNotifier.keyCustomTargetLanguage:
          'Portuguese (Brazil)',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(translationLanguagePreferencesProvider).sourceLanguage,
      TranslationSourceLanguage.automatic,
    );
    await _pumpAsyncPreferenceLoad();

    var preferences = container.read(translationLanguagePreferencesProvider);
    expect(preferences.sourceLanguage, TranslationSourceLanguage.japanese);
    expect(preferences.targetLanguage, TranslationTargetLanguage.english);
    expect(preferences.customSourceLanguage, 'Korean');
    expect(preferences.customTargetLanguage, 'Portuguese (Brazil)');

    final notifier =
        container.read(translationLanguagePreferencesProvider.notifier);
    await notifier.updateSourceLanguage(TranslationSourceLanguage.custom);
    await notifier.updateTargetLanguage(TranslationTargetLanguage.custom);
    await notifier.updateCustomSourceLanguage('  Spanish  ');
    await notifier.updateCustomTargetLanguage('  Korean  ');

    preferences = container.read(translationLanguagePreferencesProvider);
    final prefs = await SharedPreferences.getInstance();

    expect(preferences.sourceLanguage, TranslationSourceLanguage.custom);
    expect(preferences.targetLanguage, TranslationTargetLanguage.custom);
    expect(preferences.customSourceLanguage, 'Spanish');
    expect(preferences.customTargetLanguage, 'Korean');
    expect(
      prefs.getString(TranslationLanguagePreferencesNotifier.keySourceLanguage),
      TranslationSourceLanguage.custom.value,
    );
    expect(
      prefs.getString(TranslationLanguagePreferencesNotifier.keyTargetLanguage),
      TranslationTargetLanguage.custom.value,
    );
    expect(
      prefs.getString(
          TranslationLanguagePreferencesNotifier.keyCustomSourceLanguage),
      'Spanish',
    );
    expect(
      prefs.getString(
          TranslationLanguagePreferencesNotifier.keyCustomTargetLanguage),
      'Korean',
    );
  });

  test('LLM default prompt uses custom source and target languages', () async {
    SharedPreferences.setMockInitialValues({
      'translation_source': TranslationSource.llm.value,
      TranslationLanguagePreferencesNotifier.keySourceLanguage:
          TranslationSourceLanguage.custom.value,
      TranslationLanguagePreferencesNotifier.keyTargetLanguage:
          TranslationTargetLanguage.custom.value,
      TranslationLanguagePreferencesNotifier.keyCustomSourceLanguage: 'Korean',
      TranslationLanguagePreferencesNotifier.keyCustomTargetLanguage:
          'Portuguese (Brazil)',
    });

    final prompt =
        await TranslationService().getDefaultLLMPromptForCurrentLocale();

    expect(prompt, contains('from Korean'));
    expect(prompt, contains('into Portuguese (Brazil)'));
  });

  test('identifies generated default LLM prompts', () {
    final prompt = TranslationService.getDefaultLLMPrompt(
      const Locale('en'),
      sourceLanguageName: 'Japanese',
      targetLanguageName: 'Korean',
    );

    expect(TranslationService.isGeneratedDefaultLLMPrompt(prompt), true);
    expect(
      TranslationService.isGeneratedDefaultLLMPrompt(
        'Translate casually and keep honorifics.',
      ),
      false,
    );
  });

  test('non-LLM prompt ignores custom languages and follows app language',
      () async {
    SharedPreferences.setMockInitialValues({
      'translation_source': TranslationSource.google.value,
      'locale_language': 'en',
      TranslationLanguagePreferencesNotifier.keySourceLanguage:
          TranslationSourceLanguage.custom.value,
      TranslationLanguagePreferencesNotifier.keyTargetLanguage:
          TranslationTargetLanguage.custom.value,
      TranslationLanguagePreferencesNotifier.keyCustomSourceLanguage: 'Korean',
      TranslationLanguagePreferencesNotifier.keyCustomTargetLanguage:
          'Portuguese (Brazil)',
    });

    final prompt =
        await TranslationService().getDefaultLLMPromptForCurrentLocale();

    expect(prompt, isNot(contains('from Korean')));
    expect(prompt, isNot(contains('Portuguese (Brazil)')));
    expect(prompt, contains('into English'));
  });
}
