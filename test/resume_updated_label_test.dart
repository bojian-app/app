import 'package:bojian_mobile/resume_updated_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Recent updates use local calendar days and keep the time', () {
    final now = DateTime(2026, 10, 8, 0, 5);
    expect(
      resumeUpdatedLabel(DateTime(2026, 10, 8, 0, 1), now: now),
      '今天 00:01',
    );
    expect(
      resumeUpdatedLabel(DateTime(2026, 10, 7, 23, 50), now: now),
      '昨天 23:50',
    );
    expect(
      resumeUpdatedLabel(DateTime(2026, 10, 6, 13, 50), now: now),
      '前天 13:50',
    );
    expect(
      resumeUpdatedLabel(DateTime(2026, 10, 5, 13, 50), now: now),
      '10月5日 13:50',
    );
  });

  test('Relative days work across months and years', () {
    expect(
      resumeUpdatedLabel(
        DateTime(2025, 12, 31, 13, 50),
        now: DateTime(2026, 1, 1),
      ),
      '昨天 13:50',
    );
    expect(
      resumeUpdatedLabel(
        DateTime(2026, 9, 30, 13, 50),
        now: DateTime(2026, 10, 1),
      ),
      '昨天 13:50',
    );
  });

  test('Older years and future dates show explicit dates', () {
    final now = DateTime(2026, 10, 8);
    expect(
      resumeUpdatedLabel(DateTime(2025, 10, 5, 9, 5), now: now),
      '2025年10月5日 09:05',
    );
    expect(
      resumeUpdatedLabel(DateTime(2026, 10, 9, 9, 5), now: now),
      '10月9日 09:05',
    );
  });

  test('UTC timestamps use the same local time as local timestamps', () {
    final local = DateTime(2026, 10, 7, 13, 50);
    expect(
      resumeUpdatedLabel(local.toUtc(), now: DateTime(2026, 10, 8)),
      '昨天 13:50',
    );
  });
}
