import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/storage/personalization_store.dart';
import 'package:v_shots/features/onboarding/onboarding_screen.dart';
import 'package:v_shots/shared/widgets/app_text_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool completed;

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    OnboardingSongSearch? songSearch,
  }) async {
    completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () => completed = true,
          songSearch: songSearch,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonalizationStore.instance.reset();
    await PersonalizationStore.instance.initialize();
  });

  tearDown(() async {
    await PersonalizationStore.instance.reset();
  });

  testWidgets(
      'full flow persists languages, artists, songs and genres; '
      'blocked songs are never offered', (tester) async {
    // A search source that (deliberately) returns a blocked-channel track —
    // the picker itself must filter it out.
    Future<List<Map<String, dynamic>>> songSearch(String query) async {
      return <Map<String, dynamic>>[
        {
          'id': 'clean1111111',
          'title': 'Clean Song',
          'artist': 'Some Artist',
          'channelTitle': 'T-Series',
        },
        {
          'id': 'blocked11111',
          'title': 'Blocked Song',
          'artist': 'Prakash Jojawar',
          'channelTitle': 'Prakash Jojawar',
        },
      ];
    }

    await pumpOnboarding(tester, songSearch: songSearch);

    // Welcome → Languages.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Artists.
    await tester.tap(find.text('Arijit Singh'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Songs: search, wait for debounce, verify blocked content is absent.
    await tester.enterText(find.byType(AppTextInput).first, 'romantic');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Clean Song'), findsOneWidget);
    expect(find.text('Blocked Song'), findsNothing);
    await tester.tap(find.text('Clean Song'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Genres.
    await tester.tap(find.text('Romantic'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Review reflects every selection. The review is a lazy ListView —
    // later sections (genres) live below the fold in the test viewport.
    expect(find.text('Your taste profile'), findsOneWidget);
    expect(find.text('Hindi'), findsWidgets);
    expect(find.text('Arijit Singh'), findsWidgets);
    expect(find.text('Clean Song'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Romantic'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Romantic'), findsWidgets);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump();

    expect(completed, isTrue);
    final store = PersonalizationStore.instance;
    expect(store.onboarded, isTrue);
    expect(store.preferredLanguages, ['Hindi']);
    expect(store.favoriteArtists, ['Arijit Singh']);
    expect(store.preferredGenres, ['Romantic']);
    expect(store.favoriteSongs, hasLength(1));
    expect(store.favoriteSongs.first.id, 'clean1111111');
  });

  testWidgets('skip completes onboarding without forcing preferences',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(completed, isTrue);
    expect(PersonalizationStore.instance.onboarded, isTrue);
    expect(PersonalizationStore.instance.hasPreferences, isFalse);
  });

  testWidgets('skip still saves whatever the user already picked',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punjabi'));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(completed, isTrue);
    expect(PersonalizationStore.instance.preferredLanguages, ['Punjabi']);
  });

  testWidgets('back navigation preserves earlier selections', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Artists step → back to languages.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsWidgets);

    // The chip still shows as selected (tap toggles OFF — verify state by
    // deselecting and re-selecting cleanly).
    await tester.tap(find.text('English')); // deselect
    await tester.tap(find.text('English')); // reselect
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
  });

  testWidgets('clear-all removes every selection on a step', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi'));
    await tester.pump();
    await tester.tap(find.text('Punjabi'));
    await tester.pump();
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('custom artist can be added via search when not curated',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // languages (none picked)
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(AppTextInput).first, 'Neha Kakkar');
    await tester.pump();
    // Curated match exists — no "Add" chip needed.
    expect(find.text('Neha Kakkar'), findsWidgets);

    await tester.enterText(find.byType(AppTextInput).first, 'Zubaan Wale');
    await tester.pump();
    expect(find.text('Add "Zubaan Wale"'), findsOneWidget);
    await tester.tap(find.text('Add "Zubaan Wale"'));
    await tester.pump();
    expect(find.text('Zubaan Wale'), findsWidgets);
  });
}
