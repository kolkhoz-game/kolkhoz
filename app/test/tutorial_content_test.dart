import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/tutorial_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('base tutorial asset owns the complete editable walkthrough', () async {
    final content = await loadBaseTutorialContent();

    expect(content.orientationStops, hasLength(7));
    expect(content.steps, hasLength(20));
    expect(content.steps[content.firstMatchStepIndex].id, 'reward-cards');
    expect(
      content.steps.singleWhere((step) => step.id == 'reward-cards'),
      isA<TutorialStepContent>()
          .having((step) => step.autoAdvance, 'autoAdvance', isFalse)
          .having(
            (step) => step.continueAction,
            'continueAction',
            'completeTutorialRewardLesson',
          ),
    );
    expect(
      content.orientationHeader.resolve(KolkhozLanguage.ru),
      'ГОД 0 · ЗНАКОМСТВО',
    );
    expect(
      content.steps
          .singleWhere((step) => step.id == 'saboteur-assignment')
          .tip(KolkhozLanguage.en),
      contains('guaranteed to fail'),
    );
    final assignment = content.steps.singleWhere(
      (step) => step.id == 'assign-labor',
    );
    expect(assignment.title(KolkhozLanguage.en), 'You are the brigade leader');
    expect(assignment.body(KolkhozLanguage.en), contains('third trick'));
    expect(
      assignment.body(KolkhozLanguage.en),
      contains('same highlighted job'),
    );
    expect(
      content.steps
          .singleWhere((step) => step.id == 'split-assignment')
          .body(KolkhozLanguage.en),
      contains('Wheat and Beet'),
    );
    expect(
      content.steps
          .singleWhere((step) => step.id == 'requisition')
          .body(KolkhozLanguage.en),
      contains('Beet King'),
    );
    expect(
      content.steps
          .singleWhere((step) => step.id == 'hero-within-reach')
          .tip(KolkhozLanguage.en),
      contains('Hero of Socialist Labor'),
    );
    expect(
      content.steps
          .singleWhere((step) => step.id == 'hero-of-socialist-labor')
          .body(KolkhozLanguage.en),
      contains('protected from ordinary requisition'),
    );
  });

  test('stable resume keys survive tutorial reordering', () async {
    final content = await loadBaseTutorialContent();

    expect(
      content.steps[content.stepIndexForResumeKey('year1.trick')].id,
      'play-card',
    );
    expect(
      content.steps[content.stepIndexForResumeKey('year2.requisition')].id,
      'requisition',
    );
    expect(
      content.steps[content.stepIndexForResumeKey('year2.firstAssignment')].id,
      'split-assignment',
    );
    expect(
      content.steps[content.stepIndexForResumeKey('gameOver')].id,
      'final-score',
    );
    expect(
      content.steps[content.stepIndexForResumeKey('year5.finalTrick')].id,
      'hero-within-reach',
    );
  });

  test('tutorial parser reports invalid authoring values', () {
    expect(
      () => parseTutorialContent('''
        {
          "version": 1,
          "orientation": {
            "header": {"en": "Header", "ru": "Заголовок"},
            "beginLabel": {"en": "Begin", "ru": "Начать"},
            "stops": [{
              "id": "tour",
              "title": {"en": "Tour", "ru": "Тур"},
              "body": {"en": "Body", "ru": "Текст"},
              "focus": "somewhere"
            }]
          },
          "firstMatchStepId": "lesson",
          "steps": [{
            "id": "lesson",
            "title": {"en": "Lesson", "ru": "Урок"},
            "body": {"en": "Body", "ru": "Текст"},
            "tip": {"en": "Tip", "ru": "Совет"},
            "callout": {"en": "Act", "ru": "Действие"},
            "icon": "asset.png",
            "focus": "none",
            "advance": "manual"
          }]
        }
      '''),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('orientation.stops[0].focus'),
        ),
      ),
    );
  });
}
