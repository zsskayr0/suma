import 'package:flutter/material.dart';

import 'suma_floating_sheet.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const _weekdayLetters = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

/// A compact, floating calendar card in Suma's own style - closer to the
/// Apple/Notion reference (small, centered, rounded on every corner, soft
/// shadow) than Flutter's stock full-width Material date picker.
Future<DateTime?> showSumaDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showSumaFloatingSheet<DateTime>(
    context,
    maxWidth: 340,
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

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final gridStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _NavButton(icon: Icons.chevron_left_rounded, onTap: _canGoPrev ? () => _shiftMonth(-1) : null),
              Expanded(
                child: Center(
                  child: Text(
                    '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_isSelectable(today))
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hoje',
                  onPressed: () => Navigator.of(context).pop(DateTime(today.year, today.month, today.day)),
                  icon: Icon(Icons.today_rounded, size: 18, color: scheme.primary),
                )
              else
                const SizedBox(width: 40),
              _NavButton(icon: Icons.chevron_right_rounded, onTap: _canGoNext ? () => _shiftMonth(1) : null),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final l in _weekdayLetters)
                Expanded(
                  child: Center(
                    child: Text(l, style: TextStyle(fontSize: 9.5, letterSpacing: 0.4, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
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
                fg = scheme.onSurfaceVariant.withValues(alpha: 0.35);
              }

              return Padding(
                padding: const EdgeInsets.all(2),
                child: Material(
                  color: bg ?? Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? () => Navigator.of(context).pop(day) : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: isToday && !isSelected ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 1.3)) : null,
                      child: Text('${day.day}', style: TextStyle(fontSize: 13.5, color: fg, fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: onTap == null ? scheme.onSurfaceVariant.withValues(alpha: 0.3) : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
