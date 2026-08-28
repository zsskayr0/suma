import 'package:flutter/material.dart';

import 'suma_glass_sheet.dart';

/// A compact single-select glass menu - same flat+blur recipe as the rest of
/// the app's sheets/dialogs (see [showSumaGlassSheet]) - used for short
/// picker lists (Unidade de peso, Unidade de medida). Tapping an option just
/// highlights it - closing (and applying the change) needs an explicit tap
/// on "Confirmar", same as every other editor sheet in the app.
Future<T?> showSumaOptionMenu<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required List<String> labels,
  required T selected,
  List<IconData>? icons,
}) {
  return showSumaGlassSheet<T>(
    context,
    maxWidth: 340,
    builder: (ctx) => _OptionMenuBody<T>(title: title, values: values, labels: labels, initial: selected, icons: icons),
  );
}

class _OptionMenuBody<T> extends StatefulWidget {
  final String title;
  final List<T> values;
  final List<String> labels;
  final T initial;
  final List<IconData>? icons;
  const _OptionMenuBody({required this.title, required this.values, required this.labels, required this.initial, required this.icons});

  @override
  State<_OptionMenuBody<T>> createState() => _OptionMenuBodyState<T>();
}

class _OptionMenuBodyState<T> extends State<_OptionMenuBody<T>> {
  late T _pending = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.values.length; i++)
            _OptionMenuItem(
              label: widget.labels[i],
              icon: widget.icons?[i],
              selected: widget.values[i] == _pending,
              onTap: () => setState(() => _pending = widget.values[i]),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_pending),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _OptionMenuItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _OptionMenuItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? scheme.primary : scheme.onSurface),
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
