import 'package:flutter/material.dart';

import '../database/database.dart';
import '../utils/date_format.dart';
import 'expenses_list_page.dart';
import 'transaction_navigation.dart';

const _rowHeight = 64.0;
const _dateColumnWidth = 64.0;
const _dayCounterWidth = 40.0;

/// An item placed on the calendar: [startDay] is a day index, [lane] a column.
class _Booking {
  final MoneyTransaction transaction;
  final DateTime start;
  int startDay = 0;
  int lane = 0;
  bool overlaps = false;

  _Booking(this.transaction, this.start);

  bool get isHotel => transaction.isHotel;
  bool get isBooked =>
      transaction.tagList.any((tag) => tag.toLowerCase() == bookedTag);
  int get nights => transaction.days < 1 ? 1 : transaction.days;
  int get calendarDays => isHotel ? nights + 1 : 1;
  int get endDay => startDay + (isHotel ? nights : 1);

  String get title {
    final t = transaction;
    if (t.comment.isNotEmpty) return t.comment;
    final visibleTags = t.tagList.where((tag) => !isReservedTransactionTag(tag));
    if (visibleTags.isNotEmpty) return visibleTags.join(' ');
    return isHotel ? 'Hotel' : 'Expense';
  }
}

/// Lists transactions tagged for the calendar.
/// Hotels cover their stay; other transactions appear on their transaction date.
class CalendarPage extends StatelessWidget {
  final AppDatabase database;

  const CalendarPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'View Expenses',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ExpensesListPage(database: database),
              ),
            ),
            icon: const Icon(Icons.receipt_long),
          ),
          SizedBox(width: 16),
          IconButton(
            tooltip: 'Add Entry',
            onPressed: () => showNewEntryPicker(context, database),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<MoneyTransaction>>(
        stream: database.watchAllTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!
              .where(
                (t) => t.tagList.any((tag) => tag.toLowerCase() == calendarTag),
              )
              .toList();
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No calendar entries yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return _CalendarView(database: database, entries: entries);
        },
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  final AppDatabase database;
  final List<MoneyTransaction> entries;

  const _CalendarView({required this.database, required this.entries});

  static DateTime _dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final bookings = [for (final t in entries) _Booking(t, _dayOf(t.date))]
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0
            ? byStart
            : b.calendarDays.compareTo(a.calendarDays);
      });

    final first = bookings.first.start;
    var totalDays = 0;
    for (final b in bookings) {
      b.startDay = b.start.difference(first).inDays;
      final endDay = b.startDay + b.calendarDays;
      if (endDay > totalDays) totalDays = endDay;
    }

    // Greedy lane assignment: the first lane that is free at the start day.
    final laneEnds = <int>[];
    for (final b in bookings) {
      var lane = laneEnds.indexWhere((end) => end <= b.startDay);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(0);
      }
      laneEnds[lane] = b.endDay;
      b.lane = lane;
    }

    // Days booked and time-slot overlap detection (checking in vs checking out on turnover days).
    final topHalfBookings = List.generate(totalDays, (_) => <_Booking>[]);
    final bottomHalfBookings = List.generate(totalDays, (_) => <_Booking>[]);
    final fullDayBookings = List.generate(totalDays, (_) => <_Booking>[]);

    for (final b in bookings.where((b) => b.isHotel)) {
      final start = b.startDay;
      final end = b.endDay;
      if (start == end) {
        bottomHalfBookings[start].add(b);
      } else {
        bottomHalfBookings[start].add(b);
        for (var d = start + 1; d < end; d++) {
          fullDayBookings[d].add(b);
        }
        topHalfBookings[end].add(b);
      }
    }

    final overlappingBookings = <_Booking>{};
    final dayHasOverlap = List<bool>.filled(totalDays, false);

    for (var d = 0; d < totalDays; d++) {
      final full = fullDayBookings[d];
      final top = topHalfBookings[d];
      final bottom = bottomHalfBookings[d];

      final hasOverlap =
          full.length > 1 ||
          (full.isNotEmpty && (top.isNotEmpty || bottom.isNotEmpty)) ||
          top.length > 1 ||
          bottom.length > 1;

      dayHasOverlap[d] = hasOverlap;
      if (hasOverlap) {
        full.forEach(overlappingBookings.add);
        top.forEach(overlappingBookings.add);
        bottom.forEach(overlappingBookings.add);
      }
    }

    for (final b in bookings) {
      b.overlaps = overlappingBookings.contains(b);
    }
    final overlapping = overlappingBookings.length;

    final scheme = Theme.of(context).colorScheme;
    final today = _dayOf(DateTime.now());
    final bottomPadding = 88 + MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        if (overlapping > 0)
          Container(
            width: double.infinity,
            color: scheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$overlapping bookings overlap',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final lanes = laneEnds.length;
                final laneWidth =
                    (constraints.maxWidth -
                        _dateColumnWidth -
                        _dayCounterWidth -
                        8) /
                    lanes;
                return SizedBox(
                  height: totalDays * _rowHeight,
                  child: Stack(
                    children: [
                      for (var d = 0; d < totalDays; d++)
                        Positioned(
                          top: d * _rowHeight,
                          left: 0,
                          right: 0,
                          height: _rowHeight,
                          child: _DayRow(
                            day: first.add(Duration(days: d)),
                            dayNumber: d + 1,
                            isToday: first.add(Duration(days: d)) == today,
                            overlapping: dayHasOverlap[d],
                          ),
                        ),
                      for (final b in bookings)
                        Positioned(
                          top: b.isHotel
                              ? b.startDay * _rowHeight + (_rowHeight / 2) + 2
                              : b.startDay * _rowHeight + (_rowHeight / 4) + 2,
                          left: _dateColumnWidth + b.lane * laneWidth,
                          width: laneWidth - 4,
                          height: b.isHotel
                              ? b.nights * _rowHeight - 4
                              : (_rowHeight / 2) - 4,
                          child: _BookingBar(
                            booking: b,
                            onTap: () => openTransaction(
                              context,
                              database,
                              b.transaction,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final int dayNumber;
  final bool isToday;
  final bool overlapping;

  const _DayRow({
    required this.day,
    required this.dayNumber,
    required this.isToday,
    required this.overlapping,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final weekend = day.weekday >= DateTime.saturday;
    final background = overlapping
        ? scheme.errorContainer.withValues(alpha: 0.4)
        : weekend
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _dateColumnWidth,
            height: _rowHeight - 1,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(color: scheme.primaryContainer)
                : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDay(day).split(',').first,
                    style: theme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                  Text(
                    '${day.day}',
                    style: theme.titleMedium?.copyWith(
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                  Text(
                    formatDay(day).split(' ')[2],
                    style: theme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: _dayCounterWidth,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      '$dayNumber',
                      style: theme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  final _Booking booking;
  final VoidCallback onTap;

  const _BookingBar({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBookedHotel = booking.isHotel && booking.isBooked;
    final background = isBookedHotel
        ? (scheme.brightness == Brightness.dark
              ? Colors.green.shade900
              : Colors.green.shade100)
        : booking.isHotel
        ? scheme.primaryContainer
        : scheme.tertiaryContainer;
    final expenseForeground = isBookedHotel
        ? (scheme.brightness == Brightness.dark
              ? Colors.green.shade100
              : Colors.green.shade900)
        : booking.isHotel
        ? scheme.onPrimaryContainer
        : scheme.onTertiaryContainer;
    final checkIn = booking.start;
    final nights = booking.nights;
    final checkOut = booking.start.add(Duration(days: nights));
    final checkInStr = '${checkIn.day}.${checkIn.month}.';
    final checkOutStr = '${checkOut.day}.${checkOut.month}.';
    final nightsStr = nights == 1 ? '1 night' : '$nights nights';
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: booking.overlaps ? scheme.error : scheme.outline,
          width: booking.overlaps ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: booking.isHotel
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nightsStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (booking.overlaps) ...[
                          Icon(
                            Icons.warning_amber,
                            size: 14,
                            color: scheme.error,
                          ),
                        ],
                        const SizedBox(width: 4),
                      ],
                    ),
                    Text(
                      '$checkInStr → $checkOutStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const infoStyle = TextStyle(
                            fontSize: 13,
                            height: 1.15,
                          );
                          final lineHeight =
                              MediaQuery.textScalerOf(context).scale(13) *
                              infoStyle.height!;
                          final maxLines = (constraints.maxHeight / lineHeight)
                              .floor()
                              .clamp(1, 1000)
                              .toInt();

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking.title,
                                  maxLines: maxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: infoStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        booking.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ).copyWith(color: expenseForeground),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
