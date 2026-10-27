import 'package:flutter_test/flutter_test.dart';
import 'package:scrubby/core/vacuum_model_names.dart';

void main() {
  test('maps Dreame integration model identifiers to product names', () {
    expect(vacuumModelDisplayName('dreame.vacuum.r2469a'), 'L10s Ultra Gen 2');
    expect(vacuumModelDisplayName('mova.vacuum.r2525a'), 'V50 Ultra');
    expect(vacuumModelDisplayName('xiaomi.vacuum.d110ch'), 'M40');
    expect(vacuumModelDisplayName('dreame.vacuum.r2438r'), 'E10');
  });

  test('contains the full supported-device catalog snapshot', () {
    expect(vacuumModelDisplayNames, hasLength(628));
    expect(
      vacuumModelDisplayNames.values.every((name) => name.trim().isNotEmpty),
      isTrue,
    );
  });

  test('normalizes model lookup and preserves unknown models', () {
    expect(
      vacuumModelDisplayName(' DREAME.VACUUM.R2469A '),
      'L10s Ultra Gen 2',
    );
    expect(
      vacuumModelDisplayName('dreame.vacuum.future'),
      'dreame.vacuum.future',
    );
    expect(vacuumModelDisplayName('   '), isNull);
    expect(vacuumModelDisplayName(null), isNull);
  });
}
