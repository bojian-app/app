import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'design.dart';

class _NumericMonthLocalizations extends CupertinoLocalizationZhHans {
  _NumericMonthLocalizations()
    : super(
        fullYearFormat: intl.DateFormat.y('zh'),
        dayFormat: intl.DateFormat.d('zh'),
        weekdayFormat: intl.DateFormat.E('zh'),
        mediumDateFormat: intl.DateFormat.MMMEd('zh'),
        singleDigitHourFormat: intl.DateFormat('HH', 'zh'),
        singleDigitMinuteFormat: intl.DateFormat.m('zh'),
        doubleDigitMinuteFormat: intl.DateFormat('mm', 'zh'),
        singleDigitSecondFormat: intl.DateFormat.s('zh'),
        decimalFormat: intl.NumberFormat.decimalPattern('zh'),
      );

  @override
  String datePickerMonth(int monthIndex) => '$monthIndex月';

  @override
  String datePickerStandaloneMonth(int monthIndex) => '$monthIndex月';
}

class _NumericMonthDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _NumericMonthDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    await GlobalCupertinoLocalizations.delegate.load(locale);
    return _NumericMonthLocalizations();
  }

  @override
  bool shouldReload(_NumericMonthDelegate old) => false;
}

Future<DateTime?> showDateWheelPicker(
  BuildContext context, {
  required String title,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool monthOnly = false,
}) {
  dismissKeyboard();
  var selected = initialDate.isBefore(firstDate)
      ? firstDate
      : initialDate.isAfter(lastDate)
      ? lastDate
      : initialDate;
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => Localizations.override(
      context: sheetContext,
      locale: const Locale('zh'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        _NumericMonthDelegate(),
        GlobalWidgetsLocalizations.delegate,
      ],
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (MediaQuery.sizeOf(sheetContext).height * .8).clamp(180, 320),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoTheme.of(sheetContext).copyWith(
                    textTheme: CupertinoTheme.of(sheetContext).textTheme
                        .copyWith(
                          dateTimePickerTextStyle:
                              CupertinoTheme.of(sheetContext)
                                  .textTheme
                                  .dateTimePickerTextStyle
                                  .copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: ink,
                                  ),
                        ),
                  ),
                  child: CupertinoDatePicker(
                    mode: monthOnly
                        ? CupertinoDatePickerMode.monthYear
                        : CupertinoDatePickerMode.date,
                    dateOrder: DatePickerDateOrder.ymd,
                    initialDateTime: selected,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    minimumYear: firstDate.year,
                    maximumYear: lastDate.year,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
