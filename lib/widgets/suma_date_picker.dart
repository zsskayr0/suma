import 'package:flutter/material.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const _weekdayLetters = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

/// A calendar-grid date picker in Suma's own style (rounded month card,
/// tap-a-day-to-pick, no dialog chrome) instead of Flutter's stock Material
/// date picker, which looks distinctly Android/Material You.
Future<DateTime?> showSumaDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SumaDatePickerSheet(initialDate: initialDate, firstDate: firstDate, lastDate: lastDate),
  );
}

class _SumaDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  const _SumaDatePickerSheet({required this.initialDate, required this.firstDate, required this.lastDate});

  @override
  State<_SumaDatePickerSheet> createState() => _SumaDatePickerSheetState();
}

class _SumaDatePickerSheetState extends State<_SumaDatePickerSheet> {
  late DateTime _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);

  DateTime get _firstMonth => DateTime(widget.firstDate.year, widget.firstDate.month);
  DateTime get _lastMonth => DateTime(widget.lastDate.year, widget.lastDate.month);

  bool get _canGoPrev => _visibleMonth.isAfter(_firstMonth);
  bool get _canGoNext => _visibleMonth.isBefore(_lastMonth);

  void _shiftMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  bool _isSelectable(DateTime day) {
    return !day.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) &&
        !day.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final selected = widget.initialDate;

    // Grid starts on the Sunday on/before the 1st of the month.
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final gridStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _canGoPrev ? () => _shiftMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoNext ? () => _shiftMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final l in _weekdayLetters)
                  Expanded(
                    child: Center(
                      child: Text(l, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemBuilder: (context, i) {
                final day = days[i];
                final inMonth = day.month == _visibleMonth.month;
                final isToday = _sameDay(day, today);
                final isSelected = _sameDay(day, selected);
                final enabled = _isSelectable(day);

                Color? bg;
                Color fg = scheme.onSurface;
                if (isSelected) {
                  bg = scheme.primary;
                  fg = Colors.white;
                } else if (!enabled || !inMonth) {
                  fg = scheme.onSurfaceVariant.withValues(alpha: 0.4);
                }

                return Padding(
                  padding: const EdgeInsets.all(3),
                  child: Material(
                    color: bg ?? Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled ? () => Navigator.of(context).pop(day) : null,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: isToday && !isSelected ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 1.4)) : null,
                        child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (_isSelectable(today))
              TextButton(
                onPressed: () => Navigator.of(context).pop(DateTime(today.year, today.month, today.day)),
                child: const Text('Hoje'),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
