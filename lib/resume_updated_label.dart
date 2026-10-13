String resumeUpdatedLabel(DateTime value, {DateTime? now}) {
  final date = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  // Compare calendar dates so daylight saving transitions do not shift a day.
  final days = DateTime.utc(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  final day = switch (days) {
    0 => '今天',
    1 => '昨天',
    2 => '前天',
    _ =>
      date.year == current.year
          ? '${date.month}月${date.day}日'
          : '${date.year}年${date.month}月${date.day}日',
  };
  String two(int number) => number.toString().padLeft(2, '0');
  return '$day ${two(date.hour)}:${two(date.minute)}';
}
