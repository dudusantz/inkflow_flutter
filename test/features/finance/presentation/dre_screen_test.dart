import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/finance/presentation/dre_screen.dart';

void main() {
  test('lista todos os meses do período, inclusive sem movimentações', () {
    final months = dreMonthsInRange(
      DateTimeRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 10, 12),
      ),
    );

    expect(months, hasLength(10));
    expect(months.first, DateTime(2026, 1));
    expect(months.last, DateTime(2026, 10));
  });

  test('lista corretamente um período que atravessa o ano', () {
    final months = dreMonthsInRange(
      DateTimeRange(
        start: DateTime(2025, 11, 10),
        end: DateTime(2026, 2, 5),
      ),
    );

    expect(months, [
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
  });
}
