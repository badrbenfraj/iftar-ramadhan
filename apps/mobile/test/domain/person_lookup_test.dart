import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/domain/person_lookup.dart';

void main() {
  const a = FastingPerson(id: 1, firstName: 'A', lastName: 'A', singleMeal: 1, familyMeal: 0, cin: '08123812');
  const b = FastingPerson(id: 2, firstName: 'B', lastName: 'B', singleMeal: 1, familyMeal: 0);

  test('finds another person with the same 8-digit CIN', () {
    expect(findByCin([a, b], '08123812'), a);
    expect(findByCin([a, b], ' 08123812 '), a);
  });

  test('ignores partial CINs and the person being edited', () {
    expect(findByCin([a, b], '0812381'), isNull);
    expect(findByCin([a, b], '08123812', excludeId: 1), isNull);
    expect(findByCin([a, b], '99999999'), isNull);
  });
}
