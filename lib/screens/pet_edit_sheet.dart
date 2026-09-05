import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/pet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/suma_date_picker.dart';
import '../widgets/suma_glass_sheet.dart';

/// Add/edit a pet sub-profile (nome, data de nascimento, espécie, raça) -
/// same glass-sheet shell as the rest of the app's editors. Saving/deleting
/// happens here directly against [AppState] (unlike [EntryFormSheet], which
/// hands its result back to the caller) since there's no extra
/// screen-specific state to fold the result into.
class PetEditSheet extends StatefulWidget {
  final Pet? existing;
  const PetEditSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {Pet? existing}) {
    return showSumaGlassSheet<void>(context, builder: (_) => PetEditSheet(existing: existing));
  }

  @override
  State<PetEditSheet> createState() => _PetEditSheetState();
}

class _PetEditSheetState extends State<PetEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _speciesCtrl;
  late final TextEditingController _breedCtrl;
  DateTime? _birthDate;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _speciesCtrl = TextEditingController(text: p?.species ?? '');
    _breedCtrl = TextEditingController(text: p?.breed ?? '');
    _birthDate = p?.birthDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showSumaDatePicker(context, initialDate: _birthDate ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime.now());
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    final name = _nameCtrl.text.trim();
    final species = _speciesCtrl.text.trim();
    final breed = _breedCtrl.text.trim().isEmpty ? null : _breedCtrl.text.trim();

    try {
      if (widget.existing == null) {
        await appState.addPet(name: name, birthDate: _birthDate, species: species, breed: breed);
      } else {
        await appState.updatePet(widget.existing!.copyWith(name: name, birthDate: _birthDate, clearBirthDate: _birthDate == null, species: species, breed: breed, clearBreed: breed == null));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir ${widget.existing!.name}?'),
        content: const Text('O pet e todo o histórico de peso dele serão apagados permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.negative), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _deleting = true);
    await context.read<AppState>().deletePet(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  String _friendlyError(Object e) {
    // A PostgrestException (e.g. the "máximo de 3 pets" trigger in
    // supabase/010_pets.sql firing server-side - reachable if two devices
    // race past the client-side check above) never stringifies as
    // "Exception: ...", so it fell through to the generic message below
    // instead of surfacing its own already-Portuguese, specific reason -
    // same PostgrestException-first check the rest of the app's error
    // handlers already use (see settings_screen.dart/admin_users_screen.dart).
    if (e is PostgrestException) return e.message;
    final msg = e.toString();
    return msg.startsWith('Exception: ') ? msg.substring('Exception: '.length) : 'Não foi possível salvar. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.pets_rounded, color: scheme.primary, size: 26),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.existing == null ? 'Novo pet' : 'Editar pet', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data de nascimento - opcional',
                    suffixIcon: _birthDate == null ? null : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _birthDate = null)),
                  ),
                  child: Text(
                    _birthDate == null ? 'Não informado' : DateFormat('dd/MM/yyyy').format(_birthDate!),
                    style: TextStyle(color: _birthDate == null ? scheme.onSurfaceVariant : scheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _speciesCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Espécie', hintText: 'ex: Cachorro, Gato, Pássaro'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a espécie' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _breedCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Raça - opcional'),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Salvando...' : 'Salvar')),
              if (widget.existing != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _deleting ? null : _delete,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative), foregroundColor: AppColors.negative),
                  child: Text(_deleting ? 'Excluindo...' : 'Excluir pet'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
