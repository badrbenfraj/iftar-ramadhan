import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/core/widgets/hand_over_tiles.dart';
import 'package:iftar_mobile/core/widgets/meal_stepper.dart';
import 'package:iftar_mobile/core/widgets/state_views.dart';
import 'package:iftar_mobile/core/widgets/status_chip.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('status chip pairs an icon with the Tunisian word and time', (tester) async {
    await tester.pumpWidget(localizedApp(Scaffold(
      body: Column(children: [
        StatusChip(person: person(1), now: testNow),
        StatusChip(person: person(2, takenToday: true), now: testNow),
      ]),
    )));
    expect(find.text(isolate(MealStatusWords.notTaken)), findsOneWidget);
    // person(takenToday) was served 20 minutes before 18:30.
    expect(find.text('${isolate(MealStatusWords.taken)} ${ltr('18:10')}'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('hand-over tiles show counts and portions', (tester) async {
    // person(): 2 single meals, 1 family meal.
    await tester.pumpWidget(localizedApp(Scaffold(body: HandOverTiles(person: person(1)))));
    expect(find.text(ltr('1')), findsOneWidget);
    expect(find.text(ltr('2')), findsOneWidget);
    expect(find.text(en.portions(4)), findsOneWidget);
    expect(find.text(en.portions(2)), findsOneWidget);
  });

  testWidgets('a person with no meals set shows "none" twice', (tester) async {
    const nobody = FastingPerson(
      id: 9,
      firstName: 'A',
      lastName: 'B',
      singleMeal: 0,
      familyMeal: 0,
    );
    await tester.pumpWidget(localizedApp(const Scaffold(body: HandOverTiles(person: nobody))));
    expect(find.text(en.none), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal stepper stays within bounds', (tester) async {
    var value = 9;
    await tester.pumpWidget(localizedApp(StatefulBuilder(
      builder: (context, setState) => Scaffold(
        body: MealStepper(
          label: 'Single meal',
          caption: '1 portion',
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    )));
    await tester.tap(find.byTooltip(en.decrease));
    await tester.pump();
    expect(value, 8);
    await tester.tap(find.byTooltip(en.increase));
    await tester.pump();
    await tester.tap(find.byTooltip(en.increase)); // at max: disabled
    await tester.pump();
    expect(value, 9);
  });

  testWidgets('error view localizes the failure', (tester) async {
    await tester.pumpWidget(localizedApp(Scaffold(
      body: ErrorView(failure: const NetworkFailure(), onRetry: () {}),
    )));
    expect(find.text(en.titleOffline), findsOneWidget);
    expect(find.text(en.errNetwork), findsOneWidget);
    expect(find.text(en.tryAgain), findsOneWidget);
  });
}
