import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import '../widgets/suma_date_picker.dart';
import '../widgets/suma_glass_sheet.dart';

/// The register-entry panel: a centered "liquid glass" card (always dark,
/// regardless of the app's own theme) styled after a precision design tool
/// (Figma/macOS) rather than a standard mobile form - ultra-thin outline
/// icons, hairline field borders instead of filled chips, white/off-white
/// text at a lighter weight. Used both to add a new measurement and to edit
/// an existing one (pass [existing] for the edit case). The weight field is
/// shown in whichever unit the logged-in user prefers, converting to/from kg
/// (the storage unit) transparently.
class EntryFormSheet extends StatefulWidget {
  final WeightEntry? existing;

  const EntryFormSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {WeightEntry? existing}) {
    return showSumaGlassSheet(
      context,
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
    final picked = await showSumaDatePicker(
      context,
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

  static const _labelStyle = TextStyle(color: Colors.white60, fontWeight: FontWeight.w500, fontSize: 13.5);
  static const _valueStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15);

  InputDecoration _fieldDecoration({required String label, required HeroIcons icon}) {
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      labelText: label,
      labelStyle: _labelStyle,
      floatingLabelStyle: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w600, fontSize: 13),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: HeroIcon(icon, style: HeroIconStyle.outline, size: 18, color: Colors.white54),
      ),
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(Colors.white.withValues(alpha: 0.16), 1),
      border: border(Colors.white.withValues(alpha: 0.16), 1),
      focusedBorder: border(AppColors.cyan.withValues(alpha: 0.85), 1.3),
      errorBorder: border(AppColors.negative.withValues(alpha: 0.7), 1),
      focusedErrorBorder: border(AppColors.negative, 1.3),
      errorStyle: const TextStyle(color: AppColors.negative, fontSize: 11.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Novo registro' : 'Editar registro',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 19),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: HeroIcon(HeroIcons.xMark, style: HeroIconStyle.outline, size: 20, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _fieldDecoration(label: 'Data', icon: HeroIcons.calendar),
                  child: Text(DateFormat('dd/MM/yyyy').format(_date), style: _valueStyle),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _weightCtrl,
                style: _valueStyle,
                cursorColor: AppColors.cyan,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                decoration: _fieldDecoration(label: 'Peso (${Units.label(_unitPref)})', icon: HeroIcons.scale),
                validator: (v) => _parse(v ?? '') == null ? 'Informe o peso' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fatCtrl,
                style: _valueStyle,
                cursorColor: AppColors.cyan,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                decoration: _fieldDecoration(label: 'Gordura corporal (%) - opcional', icon: HeroIcons.chartPie),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = _parse(v);
                  if (val == null) return 'Valor inválido';
                  if (val < 0 || val > 100) return 'Deve estar entre 0 e 100';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hydrationCtrl,
                style: _valueStyle,
                cursorColor: AppColors.cyan,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                decoration: _fieldDecoration(label: 'Hidratação (%) - opcional', icon: HeroIcons.beaker),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = _parse(v);
                  if (val == null) return 'Valor inválido';
                  if (val < 0 || val > 100) return 'Deve estar entre 0 e 100';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                style: _valueStyle,
                cursorColor: AppColors.cyan,
                decoration: _fieldDecoration(label: 'Notas - opcional', icon: HeroIcons.documentText),
                maxLines: 2,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const HeroIcon(HeroIcons.check, style: HeroIconStyle.solid, size: 18),
                label: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
