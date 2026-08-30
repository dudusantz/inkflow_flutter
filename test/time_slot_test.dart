import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/core/utils/time_slot.dart';

void main() {
  group('TimeSlot.parseMinutes', () {
    test('aceita HH:mm e o HH:mm:ss devolvido pelo Postgres', () {
      expect(TimeSlot.parseMinutes('09:30'), 570);
      expect(TimeSlot.parseMinutes('09:30:00'), 570);
      expect(TimeSlot.parseMinutes('9:05'), 545);
    });

    test('rejeita entrada livre em vez de virar zero silenciosamente', () {
      // O parser anterior fazia `split(':')` e caía em 0 para qualquer coisa
      // fora do formato, o que zerava a checagem de conflito.
      expect(TimeSlot.parseMinutes('9h'), isNull);
      expect(TimeSlot.parseMinutes('manhã'), isNull);
      expect(TimeSlot.parseMinutes(''), isNull);
      expect(TimeSlot.parseMinutes(null), isNull);
    });

    test('rejeita hora ou minuto fora do intervalo', () {
      expect(TimeSlot.parseMinutes('24:00'), isNull);
      expect(TimeSlot.parseMinutes('10:60'), isNull);
    });
  });

  group('TimeSlot.normalize', () {
    test('descarta os segundos e completa com zero à esquerda', () {
      expect(TimeSlot.normalize('9:05:00'), '09:05');
      expect(TimeSlot.normalize('14:00'), '14:00');
    });

    test('devolve null para valor irreconhecível', () {
      expect(TimeSlot.normalize('meio-dia'), isNull);
    });
  });

  group('TimeSlot.tryParse', () {
    test('exige que o fim venha depois do início', () {
      expect(TimeSlot.tryParse('14:00', '13:00'), isNull);
      expect(TimeSlot.tryParse('14:00', '14:00'), isNull);
      expect(TimeSlot.tryParse('14:00', '15:00'), isNotNull);
    });
  });

  group('TimeSlot.overlaps — conflito de agenda', () {
    TimeSlot slot(String start, String end) => TimeSlot.tryParse(start, end)!;

    test('detecta sobreposição parcial nos dois sentidos', () {
      expect(slot('09:00', '11:00').overlaps(slot('10:00', '12:00')), isTrue);
      expect(slot('10:00', '12:00').overlaps(slot('09:00', '11:00')), isTrue);
    });

    test('detecta sessão contida em outra', () {
      expect(slot('09:00', '18:00').overlaps(slot('10:00', '11:00')), isTrue);
    });

    test('sessões encostadas não conflitam', () {
      expect(slot('09:00', '11:00').overlaps(slot('11:00', '13:00')), isFalse);
    });

    test('sessões distantes não conflitam', () {
      expect(slot('09:00', '10:00').overlaps(slot('15:00', '16:00')), isFalse);
    });
  });
}
