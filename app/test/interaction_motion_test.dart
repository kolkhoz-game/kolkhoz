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

    setState(() => panel = 1);
    await tester.pump();
    expect(find.text('panel 0'), findsOneWidget);
    expect(find.text('panel 1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('panel 0'), findsNothing);
    expect(find.text('panel 1'), findsOneWidget);
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
      matching: find.byType(TactileControlSurface),
    );
    expect(dismiss, findsOneWidget);

    await tester.tap(dismiss);
    expect(focusedSurfaceID, isNull);
  });
}
