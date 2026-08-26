import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../utils/units.dart';

/// Bottom sheet used both to add a new measurement and to edit an existing
/// one (pass [existing] for the edit case). The weight field is shown in
/// whichever unit the logged-in user prefers, converting to/from kg (the
/// storage unit) transparently.
class EntryFormSheet extends StatefulWidget {
  final WeightEntry? existing;

  const EntryFormSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {WeightEntry? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntryFormSheet(existing: existing),
    );
  }

  @override
  State<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _hydrationCtrl;
  late final TextEditingController _notesCtrl;
  late String _unitPref;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _unitPref = context.read<AppState>().currentProfile?.unitPref ?? 'kg';
    _date = e?.date ?? DateTime.now();
    _weightCtrl = TextEditingController(text: e != null ? _fmt(Units.displayValue(e.weightKg, _unitPref)) : '');
    _fatCtrl = TextEditingController(text: e?.bodyFatPct != null ? _fmt(e!.bodyFatPct!) : '');
    _hydrationCtrl = TextEditingController(text: e?.hydrationPct != null ? _fmt(e!.hydrationPct!) : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  String _fmt(double v) => v == (v.truncateToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _weightCtrl.dispose();
    _fatCtrl.dispose();
    _hydrationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final weight = Units.toKg(_parse(_weightCtrl.text)!, _unitPref);
    final fat = _parse(_fatCtrl.text);
    final hydration = _parse(_hydrationCtrl.text);
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (widget.existing == null) {
      await appState.addEntry(date: _date, weightKg: weight, bodyFatPct: fat, hydrationPct: hydration, notes: notes);
    } else {
      await appState.updateEntry(widget.existing!.copyWith(
        date: _date,
        weightKg: weight,
        bodyFatPct: fat,
        hydrationPct: hydration,
        notes: notes,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(
                widget.existing == null ? 'Novo registro' : 'Editar registro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.event_outlined)),
                  child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Peso (${Units.label(_unitPref)})', prefixIcon: const Icon(Icons.monitor_weight_outlined)),
                validator: (v) => _parse(v ?? '') == null ? 'Informe o peso' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fatCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Gordura corporal (%) - opcional', prefixIcon: Icon(Icons.pie_chart_outline)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = _parse(v);
                  if (val == null) return 'Valor inválido';
                  if (val < 0 || val > 100) return 'Deve estar entre 0 e 100';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hydrationCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hidratação (%) - opcional', prefixIcon: Icon(Icons.water_drop_outlined)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = _parse(v);
                  if (val == null) return 'Valor inválido';
                  if (val < 0 || val > 100) return 'Deve estar entre 0 e 100';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas - opcional', prefixIcon: Icon(Icons.notes_outlined)),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
