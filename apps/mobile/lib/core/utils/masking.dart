/// "••••• 812": enough to check a card holder, not enough to copy the CIN
/// (spec §4.6). Screens used in public show only this.
String? maskCin(String? cin) {
  final digits = cinLastDigits(cin);
  return digits == null ? null : '••••• $digits';
}

String? cinLastDigits(String? cin) {
  final value = cin?.trim();
  if (value == null || value.length < 3) return null;
  return value.substring(value.length - 3);
}
