import 'package:bojian_mobile/resume_work_experience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sortByRecency puts current and latest entries first', () {
    final entries = [
      ('a', '2018-03-01', '2020-06-01'),
      ('b', '', ''),
      ('c', '2022-05-10', '至今'),
      ('d', '2020-07', '2022-04'),
      ('e', '2016-09-01', ''),
    ];
    sortByRecency(entries, (e) => e.$2, (e) => e.$3);
    expect(entries.map((e) => e.$1), ['c', 'd', 'a', 'e', 'b']);
  });

  test('sortByRecency supports single-date entries', () {
    final entries = ['2019/05', '', '2023.01', '2021-08-01'];
    sortByRecency(entries, (e) => e);
    expect(entries, ['2023.01', '2021-08-01', '2019/05', '']);
  });
}
