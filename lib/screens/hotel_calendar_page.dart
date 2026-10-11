import 'package:flutter/material.dart';
import '../database/database.dart';
import '../utils/date_format.dart';
import '../widgets/hotel_state_badge.dart';
import 'hotel_page.dart';
import 'transaction_navigation.dart';

const _rowHeight = 64.0;
const _dateColumnWidth = 64.0;

/// A booking placed on the calendar: [startDay] is a day index, [lane] a column.
class _Booking {
  final MoneyTransaction transaction;
  final DateTime start;
  final int length;
  int startDay = 0;
  int lane = 0;
  bool overlaps = false;

  _Booking(this.transaction, this.start, this.length);

  int get endDay => startDay + length;

  String get title {
    final t = transaction;
    if (t.comment.isNotEmpty) return t.comment;
    if (t.tagList.isNotEmpty) return t.tagList.map((e) => '#$e').join(' ');
    return 'Hotel';
  }
}

/// Lists hotel bookings on a vertical calendar: one row per day, one column per
/// parallel booking. A booking covers [MoneyTransaction.date] for
/// [MoneyTransaction.days] days; overlapping bookings are highlighted.
class HotelCalendarPage extends StatelessWidget {
  final AppDatabase database;

  const HotelCalendarPage({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Calendar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<MoneyTransaction>>(
        stream: database.watchAllTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final hotels = snapshot.data!.where((t) => t.isHotel).toList();
          if (hotels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hotel, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hotel bookings yet.', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return _CalendarView(database: database, hotels: hotels);
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'hotel_calendar_fab',
        tooltip: 'Add Hotel',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HotelPage(database: database)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  final AppDatabase database;
  final List<MoneyTransaction> hotels;

  const _CalendarView({required this.database, required this.hotels});

  static DateTime _dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    // A booking of 0 days is not counted in the average but still occupies its day.
    final bookings = [
      for (final t in hotels)
        _Booking(t, _dayOf(t.date), t.days < 1 ? 1 : t.days),
    ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : b.length.compareTo(a.length);
      });

    final first = bookings.first.start;
    var last = bookings.first.start.add(Duration(days: bookings.first.length));
    for (final b in bookings) {
      final end = b.start.add(Duration(days: b.length));
      if (end.isAfter(last)) last = end;
      b.startDay = b.start.difference(first).inDays;
    }
    final totalDays = last.difference(first).inDays;

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

    // Days booked more than once, and the bookings involved.
    final occupancy = List<int>.filled(totalDays, 0);
    for (final b in bookings) {
      for (var d = b.startDay; d < b.endDay; d++) {
        occupancy[d]++;
      }
    }
    for (final b in bookings) {
      b.overlaps = occupancy.getRange(b.startDay, b.endDay).any((c) => c > 1);
    }
    final overlapping = bookings.where((b) => b.overlaps).length;

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
                    '$overlapping bookings overlap (marked in red)',
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
                    (constraints.maxWidth - _dateColumnWidth - 8) / lanes;
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
                            isToday: first.add(Duration(days: d)) == today,
                            overlapping: occupancy[d] > 1,
                          ),
                        ),
                      for (final b in bookings)
                        Positioned(
                          top: b.startDay * _rowHeight + 2,
                          left: _dateColumnWidth + b.lane * laneWidth,
                          width: laneWidth - 4,
                          height: b.length * _rowHeight - 4,
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
  final bool isToday;
  final bool overlapping;

  const _DayRow({
    required this.day,
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
            decoration: isToday ? BoxDecoration(color: scheme.primaryContainer) : null,
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
    final t = booking.transaction;
    final state = t.transactionState;
    final background = switch (state) {
      TransactionState.planned => scheme.tertiaryContainer,
      TransactionState.booked => scheme.primaryContainer,
      TransactionState.paid => Colors.green.shade100,
    };
    final end = booking.start.add(Duration(days: booking.length - 1));
    final range = booking.length == 1
        ? '${booking.start.day}.${booking.start.month}.'
        : '${booking.start.day}.${booking.start.month}. – ${end.day}.${end.month}.';
    final days = booking.length == 1 ? '1 day' : '${booking.length} days';

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: booking.overlaps ? scheme.error : scheme.outline,
          width: booking.overlaps ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (booking.overlaps) ...[
                      Icon(Icons.warning_amber, size: 16, color: scheme.error),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        booking.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                HotelStateBadge(state: state),
                const SizedBox(height: 2),
                Text(
                  '$range · $days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
