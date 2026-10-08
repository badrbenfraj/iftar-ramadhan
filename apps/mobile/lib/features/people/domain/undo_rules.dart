import '../../auth/domain/user.dart';
import 'fasting_person.dart';
import 'meal_event.dart';

/// The server accepts an undo from the volunteer who served the meal for
/// this long after it received the confirm (UNDO_WINDOW_MINUTES, spec 2A §4.2).
const serverUndoWindow = Duration(minutes: 10);

/// The meal [user] may still undo for [person], or null. Mirrors the
/// server's rule so the button only shows when it can work; the server
/// still decides. Admins may undo any meal of the day.
MealEvent? undoableMeal(FastingPerson person, User? user, DateTime now) {
  final meal = person.todayMealAt(now);
  if (meal == null || user == null) return null;
  if (user.roles.contains('ADMIN')) return meal;
  if (meal.servedById != user.id) return null;
  return now.difference(meal.servedAt) <= serverUndoWindow ? meal : null;
}
