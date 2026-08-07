import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_world_scene.dart';

void main() {
  testWidgets('matching card landing drives destination impact', (
    tester,
  ) async {
    final controller = CardMotionController();
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: CardMotionScope(
          controller: controller,
          frame: 0,
          rootKey: rootKey,
          activeCardIDs: const {},
          child: Center(
            child: MotionImpactSurface(
              impactKey: 'test',
              glowColor: Colors.red,
              matches: (impact) =>
                  impact.destination == const MotionZone.trick(1),
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );

    BoxDecoration impactDecoration() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('motion-impact-test')),
                )
                .decoration
            as BoxDecoration;

    controller.recordCardLanding(
      cardID: 'wheat-7',
      destination: const MotionZone.trick(2),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(impactDecoration().boxShadow, isEmpty);

    controller.recordCardLanding(
      cardID: 'wheat-7',
      destination: const MotionZone.trick(1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(impactDecoration().boxShadow, isNotEmpty);

    await tester.pumpAndSettle();
    expect(impactDecoration().boxShadow, isEmpty);
    controller.dispose();
  });

  testWidgets('mechanical panel switcher hands content across', (tester) async {
    final semantics = tester.ensureSemantics();
    var panel = 0;
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return SizedBox(
              width: 300,
              height: 200,
              child: MechanicalPanelSwitcher(
                panelKey: panel,
                child: Text('panel $panel'),
              ),
            );
          },
        ),
      ),
    );
    expect(find.bySemanticsLabel('panel 0'), findsOneWidget);

    setState(() => panel = 1);
    await tester.pump();
    expect(find.text('panel 0'), findsOneWidget);
    expect(find.text('panel 1'), findsOneWidget);
    expect(find.bySemanticsLabel('panel 0'), findsNothing);
    expect(find.bySemanticsLabel('panel 1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('panel 0'), findsNothing);
    expect(find.text('panel 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('interactive card flip exposes only its stable semantic node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: InteractiveCardFlip(
            concealedLabel: 'Hidden card',
            revealedLabel: 'Visible card',
            front: Semantics(
              label: 'Front artwork',
              child: SizedBox(width: 80, height: 120),
            ),
            back: Semantics(
              label: 'Back artwork',
              child: SizedBox(width: 80, height: 120),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Hidden card'), findsOneWidget);
    expect(find.bySemanticsLabel('Back artwork'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Hidden card'));
    await tester.pump();
    expect(find.bySemanticsLabel('Visible card'), findsOneWidget);
    expect(find.bySemanticsLabel('Front artwork'), findsNothing);

    semantics.dispose();
  });

  testWidgets('focused world dismiss uses tactile activation', (tester) async {
    String? focusedSurfaceID = fieldPlanWorldLayout.surfaces.first.id;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: FieldPlanWorldScene(
            cameraPosition: 0,
            overlayPage: 0,
            overlay: const SizedBox.expand(),
            focusedSurfaceID: focusedSurfaceID,
            focusProgress: 1,
            onFocusSurface: (value) => focusedSurfaceID = value,
          ),
        ),
      ),
    );

    final dismiss = find.ancestor(
      of: find.byKey(const Key('field-plan-surface-dismiss')),
      matching: find.byType(TactileButton),
    );
    expect(dismiss, findsOneWidget);

    await tester.tap(dismiss);
    expect(focusedSurfaceID, isNull);
  });
}
