import 'dart:ui';

import 'package:flutter/animation.dart' hide Interval;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../config.dart';
import '../utils.dart';
import 'visible_date_range.dart';

/// Controls the visible dates in Timetable widgets.
///
/// You can read (and listen to) the currently visible dates via [date].
///
/// To programmatically change the visible dates, use any of the following
/// functions:
/// * [animateToToday], [animateTo], or [animateToPage] if you want an animation
/// * [jumpToToday], [jumpTo], or [jumpToPage] if you don't want an animation
///
/// You can also get and update the [VisibleDateRange] via [visibleRange].
class DateController extends ValueNotifier<DatePageValue> {
  DateController({
    DateTime? initialDate,
    VisibleDateRange? visibleRange,
  })  : assert(initialDate.isValidTimetableDate),
        // We set the correct value in the body below.
        super(DatePageValue(
          visibleRange ?? VisibleDateRange.week(),
          0,
        )) {
    // The correct value is set via the listener when we assign to our value.
    _date = _DateValueNotifier(DateTimeTimetable.dateFromPage(0));
    addListener(() => _date.value = value.date);

    final rawStartPage = initialDate?.page ?? DateTimeTimetable.today().page;
    value = value.copyWith(
      page: value.visibleRange.getTargetPageForFocus(rawStartPage),
    );
  }

  late final ValueNotifier<DateTime> _date;
  ValueListenable<DateTime> get date => _date;

  VisibleDateRange get visibleRange => value.visibleRange;
  set visibleRange(VisibleDateRange visibleRange) {
    value = value.copyWith(
      page: visibleRange.getTargetPageForFocus(value.page),
      visibleRange: visibleRange,
    );
  }

  // Animation
  AnimationController? _animationController;

  Future<void> animateToToday({
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 20),
    required TickerProvider vsync,
  }) {
    return animateTo(
      DateTimeTimetable.today(),
      curve: curve,
      duration: duration,
      vsync: vsync,
    );
  }

  Future<void> animateTo(
    DateTime date, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 20),
    required TickerProvider vsync,
  }) {
    return animateToPage(
      date.page,
      curve: curve,
      duration: duration,
      vsync: vsync,
    );
  }

  Future<void> animateToPage(
    double page, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 20),
    required TickerProvider vsync,
  }) async {
    _animationController?.dispose();
    final controller =
        AnimationController(debugLabel: 'DateController', vsync: vsync);
    _animationController = controller;

    final previousPage = value.page;
    final targetPage = value.visibleRange.getTargetPageForFocus(page);
    controller.addListener(() {
      value = value.copyWith(
        page: lerpDouble(previousPage, targetPage, controller.value)!,
      );
    });

    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      controller.dispose();
      _animationController = null;
    });

    await controller.animateTo(1, duration: duration, curve: curve);
  }

  void jumpToToday() => jumpTo(DateTimeTimetable.today());
  void jumpTo(DateTime date) {
    assert(date.isValidTimetableDate);
    jumpToPage(date.page);
  }

  void jumpToPage(double page) {
    value =
        value.copyWith(page: value.visibleRange.getTargetPageForFocus(page));
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  @override
  void dispose() {
    _date.dispose();
    super.dispose();
    _isDisposed = true;
  }
}

class _DateValueNotifier extends ValueNotifier<DateTime> {
  _DateValueNotifier(DateTime date)
      : assert(date.isValidTimetableDate),
        super(date);
}

/// The value held by [DateController].
@immutable
class DatePageValue {
  const DatePageValue(this.visibleRange, this.page);

  final VisibleDateRange visibleRange;
  int get visibleDayCount => visibleRange.visibleDayCount;

  final double page;
  DateTime get date => DateTimeTimetable.dateFromPage(page.floor());

  DatePageValue copyWith({VisibleDateRange? visibleRange, double? page}) {
    return DatePageValue(visibleRange ?? this.visibleRange, page ?? this.page);
  }

  @override
  int get hashCode => hashValues(visibleRange, page);
  @override
  bool operator ==(Object other) {
    return other is DatePageValue &&
        visibleRange == other.visibleRange &&
        page == other.page;
  }

  @override
  String toString() =>
      'DatePageValue(visibleRange = $visibleRange, page = $page)';
}

/// Provides the [DateController] for Timetable widgets below it.
///
/// See also:
///
/// * [TimetableConfig], which bundles multiple configuration widgets for
///   Timetable.
class DefaultDateController extends InheritedWidget {
  const DefaultDateController({
    required this.controller,
    required Widget child,
  }) : super(child: child);

  final DateController controller;

  @override
  bool updateShouldNotify(DefaultDateController oldWidget) =>
      controller != oldWidget.controller;

  static DateController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DefaultDateController>()
        ?.controller;
  }
}
