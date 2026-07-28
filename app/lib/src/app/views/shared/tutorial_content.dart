import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:kolkhoz_app/src/app/settings/settings.dart';

const baseTutorialAssetPath = 'assets/tutorial/base_kolkhoz.json';

/// Board region highlighted while a tutorial panel is visible.
enum TutorialFocus { none, rail, jobs, table, hand }

/// Live-game event that completes a tutorial panel automatically.
enum TutorialAdvance {
  manual,
  rewardsRevealed,
  trumpChosen,
  cardPlayed,
  learnerThirdTrickWon,
  learnerThirdTrickAssigned,
  learnerYearTwoFirstMultiSuitWon,
  learnerYearTwoSecondMultiSuitWon,
  saboteurFollowPaused,
  saboteurAssignmentOpened,
  jobCompleted,
  swapPhase,
  yearTwoRequisition,
  yearThree,
  famineYear,
  learnerFamineTwoWins,
  learnerHeroProtected,
  gameOver,
}

class TutorialLocalizedText {
  const TutorialLocalizedText({required this.en, required this.ru});

  factory TutorialLocalizedText.fromJson(
    Object? value, {
    required String field,
  }) {
    final map = _jsonMap(value, field);
    return TutorialLocalizedText(
      en: _requiredString(map, 'en', '$field.en'),
      ru: _requiredString(map, 'ru', '$field.ru'),
    );
  }

  final String en;
  final String ru;

  String resolve(KolkhozLanguage language) =>
      language == KolkhozLanguage.ru ? ru : en;
}

class TutorialStepContent {
  const TutorialStepContent({
    required this.id,
    required this.titleText,
    required this.bodyText,
    required this.tipText,
    required this.calloutText,
    required this.iconPath,
    this.focus = TutorialFocus.none,
    this.advance = TutorialAdvance.manual,
    this.autoAdvance = true,
    this.continueAction,
    this.collapseAfterContinue = false,
    this.resumeAt = const [],
  });

  factory TutorialStepContent.fromJson(Object? value, int index) {
    final field = 'steps[$index]';
    final map = _jsonMap(value, field);
    return TutorialStepContent(
      id: _requiredString(map, 'id', '$field.id'),
      titleText: TutorialLocalizedText.fromJson(
        map['title'],
        field: '$field.title',
      ),
      bodyText: TutorialLocalizedText.fromJson(
        map['body'],
        field: '$field.body',
      ),
      tipText: TutorialLocalizedText.fromJson(map['tip'], field: '$field.tip'),
      calloutText: TutorialLocalizedText.fromJson(
        map['callout'],
        field: '$field.callout',
      ),
      iconPath: _requiredString(map, 'icon', '$field.icon'),
      focus: _enumByName(
        TutorialFocus.values,
        _requiredString(map, 'focus', '$field.focus'),
        '$field.focus',
      ),
      advance: _enumByName(
        TutorialAdvance.values,
        _requiredString(map, 'advance', '$field.advance'),
        '$field.advance',
      ),
      autoAdvance: map['autoAdvance'] is bool
          ? map['autoAdvance']! as bool
          : true,
      continueAction: _optionalString(
        map,
        'continueAction',
        '$field.continueAction',
      ),
      collapseAfterContinue: map['collapseAfterContinue'] is bool
          ? map['collapseAfterContinue']! as bool
          : false,
      resumeAt: _stringList(map['resumeAt'], '$field.resumeAt'),
    );
  }

  final String id;
  final TutorialLocalizedText titleText;
  final TutorialLocalizedText bodyText;
  final TutorialLocalizedText tipText;
  final TutorialLocalizedText calloutText;
  final String iconPath;
  final TutorialFocus focus;
  final TutorialAdvance advance;
  final bool autoAdvance;
  final String? continueAction;
  final bool collapseAfterContinue;
  final List<String> resumeAt;

  String title(KolkhozLanguage language) => titleText.resolve(language);

  String body(KolkhozLanguage language) => bodyText.resolve(language);

  String tip(KolkhozLanguage language) => tipText.resolve(language);

  String callout(KolkhozLanguage language) => calloutText.resolve(language);
}

class TutorialOrientationStop {
  const TutorialOrientationStop({
    required this.id,
    required this.titleText,
    required this.bodyText,
    required this.focus,
  });

  factory TutorialOrientationStop.fromJson(Object? value, int index) {
    final field = 'orientation.stops[$index]';
    final map = _jsonMap(value, field);
    return TutorialOrientationStop(
      id: _requiredString(map, 'id', '$field.id'),
      titleText: TutorialLocalizedText.fromJson(
        map['title'],
        field: '$field.title',
      ),
      bodyText: TutorialLocalizedText.fromJson(
        map['body'],
        field: '$field.body',
      ),
      focus: _enumByName(
        TutorialFocus.values,
        _requiredString(map, 'focus', '$field.focus'),
        '$field.focus',
      ),
    );
  }

  final String id;
  final TutorialLocalizedText titleText;
  final TutorialLocalizedText bodyText;
  final TutorialFocus focus;

  String title(KolkhozLanguage language) => titleText.resolve(language);

  String body(KolkhozLanguage language) => bodyText.resolve(language);
}

class TutorialContent {
  const TutorialContent({
    required this.orientationHeader,
    required this.orientationBeginLabel,
    required this.orientationStops,
    required this.firstMatchStepId,
    required this.steps,
  });

  factory TutorialContent.fromJson(Object? value) {
    final map = _jsonMap(value, 'tutorial');
    final version = map['version'];
    if (version != 1) {
      throw FormatException('tutorial.version must be 1, got $version');
    }

    final orientation = _jsonMap(map['orientation'], 'orientation');
    final stopsJson = _jsonList(orientation['stops'], 'orientation.stops');
    final stepsJson = _jsonList(map['steps'], 'steps');
    if (stopsJson.isEmpty) {
      throw const FormatException('orientation.stops must not be empty');
    }
    if (stepsJson.isEmpty) {
      throw const FormatException('steps must not be empty');
    }

    final stops = [
      for (var index = 0; index < stopsJson.length; index += 1)
        TutorialOrientationStop.fromJson(stopsJson[index], index),
    ];
    final steps = [
      for (var index = 0; index < stepsJson.length; index += 1)
        TutorialStepContent.fromJson(stepsJson[index], index),
    ];
    _requireUniqueIDs(stops.map((stop) => stop.id), 'orientation stop');
    _requireUniqueIDs(steps.map((step) => step.id), 'step');

    final firstMatchStepId = _requiredString(
      map,
      'firstMatchStepId',
      'firstMatchStepId',
    );
    if (!steps.any((step) => step.id == firstMatchStepId)) {
      throw FormatException(
        'firstMatchStepId "$firstMatchStepId" does not match a step',
      );
    }

    final resumeKeys = <String>{};
    for (final step in steps) {
      for (final key in step.resumeAt) {
        if (!resumeKeys.add(key)) {
          throw FormatException('resume key "$key" is assigned more than once');
        }
      }
    }

    return TutorialContent(
      orientationHeader: TutorialLocalizedText.fromJson(
        orientation['header'],
        field: 'orientation.header',
      ),
      orientationBeginLabel: TutorialLocalizedText.fromJson(
        orientation['beginLabel'],
        field: 'orientation.beginLabel',
      ),
      orientationStops: stops,
      firstMatchStepId: firstMatchStepId,
      steps: steps,
    );
  }

  final TutorialLocalizedText orientationHeader;
  final TutorialLocalizedText orientationBeginLabel;
  final List<TutorialOrientationStop> orientationStops;
  final String firstMatchStepId;
  final List<TutorialStepContent> steps;

  int get firstMatchStepIndex =>
      steps.indexWhere((step) => step.id == firstMatchStepId);

  int stepIndexForResumeKey(String key) {
    final index = steps.indexWhere((step) => step.resumeAt.contains(key));
    return index < 0 ? firstMatchStepIndex : index;
  }
}

Future<TutorialContent> loadBaseTutorialContent([AssetBundle? bundle]) async {
  final source = await (bundle ?? rootBundle).loadString(baseTutorialAssetPath);
  return parseTutorialContent(source);
}

TutorialContent parseTutorialContent(String source) {
  try {
    return TutorialContent.fromJson(jsonDecode(source));
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('Invalid tutorial JSON: $error');
  }
}

Map<String, Object?> _jsonMap(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be an object');
  }
  return value;
}

List<Object?> _jsonList(Object? value, String field) {
  if (value is! List<Object?>) {
    throw FormatException('$field must be an array');
  }
  return value;
}

String _requiredString(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> map, String key, String field) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

List<String> _stringList(Object? value, String field) {
  if (value == null) {
    return const [];
  }
  final values = _jsonList(value, field);
  return [
    for (var index = 0; index < values.length; index += 1)
      if (values[index] is String && (values[index]! as String).isNotEmpty)
        values[index]! as String
      else
        throw FormatException('$field[$index] must be a non-empty string'),
  ];
}

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw FormatException(
    '$field must be one of: ${values.map((value) => value.name).join(', ')}',
  );
}

void _requireUniqueIDs(Iterable<String> ids, String label) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw FormatException('Duplicate tutorial $label id "$id"');
    }
  }
}
