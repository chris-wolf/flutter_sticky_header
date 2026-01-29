import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:sliver_tools/sliver_tools.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BidirectionalScrollPage(),
  ));
}

class MockEvent {
  final String title;
  final String time;
  final Color color;
  MockEvent(this.title, this.time, this.color);
}

class BidirectionalScrollPage extends StatefulWidget {
  const BidirectionalScrollPage({super.key});

  @override
  State<BidirectionalScrollPage> createState() =>
      _BidirectionalScrollPageState();
}

class _BidirectionalScrollPageState extends State<BidirectionalScrollPage> {
  // The Key that defines "Offset 0.0"
  final Key _centerKey = const ValueKey('center-sliver');
  final ScrollController _scrollController = ScrollController();

  // Data
  late Map<DateTime, List<MockEvent>> _groupedEvents;
  late List<DateTime> _sortedMonths;

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  void _generateMockData() {
    _groupedEvents = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final random = Random();

    // 1. Create Today
    _groupedEvents[today] = [
      MockEvent("Today's Key Event", "12:00", Colors.indigo),
    ];

    // 2. Generate +/- 6 months
    for (int i = -6; i <= 6; i++) {
      for (int j = 0; j < 4; j++) {
        // Random days
        final date = DateTime(today.year, today.month + i, random.nextInt(28) + 1);
        final dateKey = DateTime(date.year, date.month, date.day);

        if (!DateUtils.isSameDay(dateKey, today)) {
          if (!_groupedEvents.containsKey(dateKey)) {
            _groupedEvents[dateKey] = [];
          }
          _groupedEvents[dateKey]!.add(MockEvent(
            "Event #${random.nextInt(99)}",
            "10:00",
            Colors.primaries[random.nextInt(Colors.primaries.length)],
          ));
        }
      }
    }

    // Get all unique months
    final monthSet = _groupedEvents.keys.map((e) => DateTime(e.year, e.month)).toSet();
    _sortedMonths = monthSet.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bidirectional Calendar")),
      body: CustomScrollView(
        controller: _scrollController,
        center: _centerKey, // Anchors the view to the sliver with this Key
        anchor: 0.0,
        slivers: _buildSlivers(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.today),
        onPressed: () => _scrollController.animateTo(0, duration: const Duration(seconds: 1), curve: Curves.easeInOut),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Widget> pastSlivers = [];
    List<Widget> futureSlivers = [];
    Widget? centerSliver;

    // We process months in standard order first
    for (var monthDate in _sortedMonths) {
      final isCurrentMonth = monthDate.year == today.year && monthDate.month == today.month;

      // Get days for this month
      final daysInMonth = _groupedEvents.keys
          .where((k) => k.year == monthDate.year && k.month == monthDate.month)
          .toList()
        ..sort(); // Default sort (1st -> 31st)

      if (isCurrentMonth) {
        // --- SPLIT CURRENT MONTH ---

        // 1. PAST DAYS of current month (e.g. Jan 1 - Jan 28)
        // REVERSE SORT so Jan 28 is closest to Jan 29
        final daysBefore = daysInMonth.where((d) => d.isBefore(today)).toList().reversed.toList();
        if (daysBefore.isNotEmpty) {
          // Notice: We pass isReverse: true
          pastSlivers.add(_buildMonthSliver(monthDate, daysBefore.toList(), isReverse: true));
        }

        // 2. TODAY (The Center Anchor)
        final daysToday = daysInMonth.where((d) => DateUtils.isSameDay(d, today)).toList();

        // We MUST assign the Key to this exact widget
        centerSliver = _buildMonthSliver(monthDate, daysToday, key: _centerKey, isReverse: false);

        // 3. FUTURE DAYS of current month (e.g. Jan 30 - Jan 31)
        final daysAfter = daysInMonth.where((d) => d.isAfter(today)).toList();
        if (daysAfter.isNotEmpty) {
          futureSlivers.add(_buildMonthSliver(monthDate, daysAfter, isReverse: false));
        }

      } else if (monthDate.isBefore(today)) {
        // --- PAST MONTH (e.g. Dec, Nov) ---
        // REVERSE DAYS: Dec 31 should be at the "Start" (Bottom), Dec 1 at "End" (Top)
        final reversedDays = daysInMonth.reversed.toList();
        // Add to START of pastSlivers list because CustomScrollView paints
        // the first item in the list closest to the center.
        // Wait! In 'slivers: []', items BEFORE the center key are painted bottom-up.
        // The one closest to the center key should be LAST in the 'pastSlivers' list.
        pastSlivers.add(_buildMonthSliver(monthDate, reversedDays, isReverse: true));

      } else {
        // --- FUTURE MONTH ---
        futureSlivers.add(_buildMonthSliver(monthDate, daysInMonth, isReverse: false));
      }
    }

    // CRITICAL: The slivers list must be: [ ...Past (reversed logic), Center, ...Future ]
    // However, for the "Past" section, the CustomScrollView expects them in order
    // growing AWAY from the center?
    // No, CustomScrollView list order is always linear.
    // [Dec, Jan-Past, Jan-Today, Jan-Future, Feb]
    // If Jan-Today is center:
    // Dec and Jan-Past are "reversed growth".
    // Dec is 'above' Jan-Past.

    // So we just combine them naturally.
    return [
      ...pastSlivers, // Dec, then Jan-Past
      if (centerSliver != null) centerSliver!,
      ...futureSlivers,
    ];
  }

  Widget _buildMonthSliver(DateTime monthDate, List<DateTime> days, {Key? key, required bool isReverse}) {
    // FIX FOR STICKY HEADER IN REVERSE:
    // In reverse mode, sticky headers stick to the BOTTOM (visually), because that is the "Start"
    // of the reverse axis.
    // To "Fix" this visually, we can't easily move the sticky header to the top without breaking the library.
    // However, standard sticky behavior means the header pushes off when the content leaves.

    return SliverStickyHeader(
      key: key,
      // If it's the past, we might want the header to appear at the 'end' (visually top)?
      // Sadly SliverStickyHeader doesn't support 'trailing' stickiness.
      // We render it as normal.
      overlapsContent: false,
      header: isReverse ? null : _buildMonthHeader(monthDate, isReverse),
      footer: isReverse ? _buildMonthHeader(monthDate, isReverse) : null,
      sliver: MultiSliver(
        children: days.map((dayDate) {
          return SliverStickyHeader(
            overlapsContent: true,
            header: _buildDayHeader(dayDate, isReverse),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(left: 96.0, top: 8.0, bottom: 20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.3))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (_groupedEvents[dayDate] ?? []).map((e) => _buildEventItem(e)).toList(),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date, bool isReverse) {
    // Visual tweak: distinguish past/future headers slightly if desired
    return Material(
      color: isReverse ? Colors.blueGrey : Colors.grey[200],
      elevation: 2.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
        width: double.infinity,
        // If it's reverse, we align text to indicate flow? No, standard is fine.
        alignment: Alignment.centerLeft,
        child: Text(
          DateFormat('MMMM yyyy').format(date),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, bool isReversed) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 96.0,
        padding: isReversed ? const EdgeInsets.fromLTRB(8, 8, 8, 32) : const EdgeInsets.all(8.0),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isToday ? Colors.indigo : Colors.black,
              ),
            ),
            Text(DateFormat.E().format(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(MockEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0, right: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.1),
        border: Border(left: BorderSide(color: event.color, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(event.time, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}