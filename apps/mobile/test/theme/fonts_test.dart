import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const files = [
    'assets/fonts/ReadexPro-300.ttf',
    'assets/fonts/ReadexPro-400.ttf',
    'assets/fonts/ReadexPro-500.ttf',
    'assets/fonts/ReadexPro-600.ttf',
    'assets/fonts/ReadexPro-700.ttf',
    'assets/fonts/ArefRuqaa-400.ttf',
    'assets/fonts/ArefRuqaa-700.ttf',
  ];

  test('bundled fonts are present and are TrueType', () async {
    for (final path in files) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(20000), reason: path);
      final magic = data.getUint32(0);
      // 0x00010000 = TrueType outlines, 0x74727565 = 'true' (Apple).
      expect(magic == 0x00010000 || magic == 0x74727565, isTrue, reason: path);
    }
  });
}
