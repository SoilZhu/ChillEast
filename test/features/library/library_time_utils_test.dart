import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/library/utils/library_time_utils.dart';

void main() {
  group('LibraryTimeUtils', () {
    test('buildTimeSlots contains all slots from 07:00 to 22:00', () {
      final slots = LibraryTimeUtils.buildTimeSlots();
      expect(slots.first, '07:00');
      expect(slots.last, '22:00');
      expect(slots.contains('12:00'), isTrue);
      expect(slots.contains('12:30'), isTrue);
    });

    test('availableReserveDays only returns today before 22:00 (UTC+8)', () {
      // 2026-09-02 21:59:59 Beijing time
      final before22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 21, 59, 59);
      final days = LibraryTimeUtils.availableReserveDays(now: before22);

      expect(days, ['2026-09-02']);
    });

    test('availableReserveDays returns today and tomorrow at or after 22:00 (UTC+8)', () {
      // 2026-09-02 22:00:00 Beijing time
      final at22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 22, 0, 0);
      final daysAt22 = LibraryTimeUtils.availableReserveDays(now: at22);
      expect(daysAt22, ['2026-09-02', '2026-09-03']);

      // 2026-09-02 23:30:00 Beijing time
      final after22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 23, 30, 0);
      final daysAfter22 = LibraryTimeUtils.availableReserveDays(now: after22);
      expect(daysAfter22, ['2026-09-02', '2026-09-03']);
    });

    test('availableReserveDays rolls over at midnight (UTC+8)', () {
      // 2026-09-03 00:00:01 Beijing time
      final afterMidnight = LibraryTimeUtils.beijingDateTime(2026, 9, 3, 0, 0, 1);
      final days = LibraryTimeUtils.availableReserveDays(now: afterMidnight);
      expect(days, ['2026-09-03']);
    });

    test('availableReserveDays handles cross-timezone UTC offsets correctly', () {
      // Suppose local device is UTC+0 at 13:59:59 UTC -> Beijing time is 21:59:59 (before 22:00)
      final utcBefore22 = DateTime.utc(2026, 9, 2, 13, 59, 59);
      expect(LibraryTimeUtils.availableReserveDays(now: utcBefore22), ['2026-09-02']);

      // 14:00:00 UTC -> Beijing time is 22:00:00 (at 22:00)
      final utcAt22 = DateTime.utc(2026, 9, 2, 14, 0, 0);
      expect(LibraryTimeUtils.availableReserveDays(now: utcAt22), ['2026-09-02', '2026-09-03']);
    });

    test('formatDayLabel formats today, tomorrow, and weekday correctly based on Beijing time', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 12, 0);

      expect(LibraryTimeUtils.formatDayLabel('2026-09-02', now: now), '今天 (9月2日)');
      expect(LibraryTimeUtils.formatDayLabel('2026-09-03', now: now), '明天 (9月3日)');
      expect(LibraryTimeUtils.formatDayLabel('2026-09-04', now: now), '周五 (9月4日)');
    });

    test('candidateEndSlots filters out past times when day is today', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 18, 36, 34);
      const today = '2026-09-02';

      final startSlots =
          LibraryTimeUtils.availableStartSlots(today, now: now);
      final endSlots =
          LibraryTimeUtils.candidateEndSlots(today, now: now);

      // Start slots should not include anything <= 18:36
      expect(startSlots.contains('07:00'), isFalse);
      expect(startSlots.contains('18:30'), isFalse);
      expect(startSlots.first, '19:00');
      expect(startSlots.last, '21:30');

      // Candidate end slots should not include anything <= 18:36
      expect(endSlots.contains('07:00'), isFalse);
      expect(endSlots.contains('18:30'), isFalse);
      expect(endSlots.first, '19:00');
      expect(endSlots.last, '22:00');
    });

    test('candidateEndSlots keeps all slots for future days', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 18, 36, 34);
      const tomorrow = '2026-09-03';

      final startSlots =
          LibraryTimeUtils.availableStartSlots(tomorrow, now: now);
      final endSlots =
          LibraryTimeUtils.candidateEndSlots(tomorrow, now: now);

      expect(startSlots.first, '07:00');
      expect(startSlots.last, '21:30');
      expect(endSlots.first, '07:00');
      expect(endSlots.last, '22:00');
    });

    test('isValidRange validates start and end times properly', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 10, 0);
      const today = '2026-09-02';
      const tomorrow = '2026-09-03';

      // Valid range in future
      expect(LibraryTimeUtils.isValidRange(today, '11:00', '13:00', now: now), isTrue);
      // Invalid: start time is in past
      expect(LibraryTimeUtils.isValidRange(today, '09:00', '11:00', now: now), isFalse);
      // Invalid: end time before start time
      expect(LibraryTimeUtils.isValidRange(today, '13:00', '11:00', now: now), isFalse);
      // Valid on tomorrow
      expect(LibraryTimeUtils.isValidRange(tomorrow, '08:00', '12:00', now: now), isTrue);
    });
  });
}
