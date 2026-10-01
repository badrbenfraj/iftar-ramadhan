/// QR cards encode the person's numeric ID as plain text (the Ionic app used
/// the scanned text directly as the ID).
sealed class QrPayload {
  const QrPayload(this.raw);

  final String raw;

  static const _maxId = 2147483647;

  static QrPayload parse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return InvalidQr(text);
    // Tolerate a leading '#' and stray whitespace; nothing else.
    final digits = text.startsWith('#') ? text.substring(1).trim() : text;
    if (!RegExp(r'^\d{1,10}$').hasMatch(digits)) return InvalidQr(text);
    final id = int.parse(digits);
    if (id <= 0 || id > _maxId) return InvalidQr(text);
    return PersonQr(text, id);
  }
}

final class PersonQr extends QrPayload {
  const PersonQr(super.raw, this.personId);

  final int personId;
}

final class InvalidQr extends QrPayload {
  const InvalidQr(super.raw);
}
