import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/pet_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import '../widgets/suma_date_picker.dart';
import '../widgets/suma_glass_sheet.dart';

/// Same panel as [EntryFormSheet] (same glass card, same field style), just
/// for a pet's own weight history - date + weight + notes only, no body
/// fat/hydration (not something tracked for pets here). Pet entries are a
/// separate table from the owner's own [WeightEntry]s - nothing about this
/// ever touches or mixes with the owner's own history.
class PetEntryFormSheet extends StatefulWidget {
  final String petId;
  final String petName;
  final String unitPref;
  final PetWeightEntry? existing;

  const PetEntryFormSheet({super.key, required this.petId, required this.petName, required this.unitPref, this.existing});

  static Future<bool?> show(BuildContext context, {required String petId, required String petName, required String unitPref, PetWeightEntry? existing}) {
    return showSumaGlassSheet<bool>(
      context,
      builder: (_) => PetEntryFormSheet(petId: petId, petName: petName, unitPref: unitPref, existing: existing),
    );
  }

  @override
  State<PetEntryFormSheet> createState() => _PetEntryFormSheetState();
}

class _PetEntryFormSheetState extends State<PetEntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _weightCtrl = TextEditingController(text: e != null ? _fmt(Units.displayValue(e.weightKg, widget.unitPref)) : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  String _fmt(double v) => v == (v.truncateToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickDate() async {
    final picked = await showSumaDatePicker(context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final weight = Units.toKg(_parse(_weightCtrl.text)!, widget.unitPref);
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (widget.existing == null) {
      await appState.addPetEntry(petId: widget.petId, date: _date, weightKg: weight, notes: notes);
    } else {
      await appState.updatePetEntry(widget.existing!.copyWith(date: _date, weightKg: weight, notes: notes, clearNotes: notes == null));
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  InputDecoration _fieldDecoration(BuildContext context, {required String label, required HeroIcons icon}) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface;
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: 13.5),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 2), child: HeroIcon(icon, style: HeroIconStyle.outline, size: 18, color: scheme.onSurfaceVariant)),
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(base.withValues(alpha: 0.16), 1),
      border: border(base.withValues(alpha: 0.16), 1),
      focusedBorder: border(scheme.primary.withValues(alpha: 0.85), 1.3),
      errorBorder: border(AppColors.negative.withValues(alpha: 0.7), 1),
      focusedErrorBorder: border(AppColors.negative, 1.3),
      errorStyle: const TextStyle(color: AppColors.negative, fontSize: 11.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onSurface;
    final valueStyle = TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15);
    return Padding(
      padding: EdgeInsets.only(left: 22, right: 22, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
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
                      widget.existing == null ? 'Novo registro de ${widget.petName}' : 'Editar registro de ${widget.petName}',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 19),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(padding: const EdgeInsets.all(6), child: HeroIcon(HeroIcons.xMark, style: HeroIconStyle.outline, size: 20, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: textColor.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _fieldDecoration(context, label: 'Data', icon: HeroIcons.calendar),
                  child: Text(DateFormat('dd/MM/yyyy').format(_date), style: valueStyle),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _weightCtrl,
                style: valueStyle,
                cursorColor: scheme.primary,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                decoration: _fieldDecoration(context, label: 'Peso (${Units.label(widget.unitPref)})', icon: HeroIcons.scale),
                validator: (v) => _parse(v ?? '') == null ? 'Informe o peso' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                style: valueStyle,
                cursorColor: scheme.primary,
                decoration: _fieldDecoration(context, label: 'Notas - opcional', icon: HeroIcons.documentText),
                minLines: 1,
                maxLines: null,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
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
