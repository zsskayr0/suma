import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/units.dart';
import '../widgets/suma_widgets.dart';

/// "Ajustes" tab: preferences (unit, theme, height, goal weight), account
/// actions (export, password) and sign-out. Replaces the old bare "Conta"
/// tab with something that actually reflects the per-user profile collected
/// during onboarding.
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenUsers;

  const SettingsScreen({super.key, this.onOpenUsers});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;

  Future<void> _exportMyData() async {
    setState(() => _exporting = true);
    final appState = context.read<AppState>();
    final user = appState.currentUser!;
    final file = await CsvExportService.exportAndHandOff(user, appState.entries);
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV salvo em: ${file.path}')));
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nova senha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (newPassword == null) return;
    if (newPassword.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter ao menos 6 caracteres.')));
      return;
    }
    if (!mounted) return;
    final appState = context.read<AppState>();
    await appState.resetPassword(appState.currentUser!, newPassword);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
  }

  Future<void> _editHeightAndGoal() async {
    final appState = context.read<AppState>();
    final user = appState.currentUser!;
    final result = await showModalBottomSheet<_ProfileEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(heightCm: user.heightCm ?? 170, goalWeightKg: user.goalWeightKg, unitPref: user.unitPref),
    );
    if (result == null) return;
    await appState.updateBodyProfile(heightCm: result.heightCm, goalWeightKg: result.goalWeightKg, clearGoal: result.goalWeightKg == null);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser!;
    final wide = Responsive.isDesktop(context);

    final profileCard = SumaCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            child: Text(
              user.name.trim().isEmpty ? '?' : user.name.trim()[0].toUpperCase(),
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('@${user.username}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Pill(text: user.isAdmin ? 'Administrador' : 'Usuário', color: user.isAdmin ? AppColors.goalAccent : Theme.of(context).colorScheme.primary),
        ],
      ),
    );

    final preferencesCard = SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unidade de peso', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'kg', label: Text('Quilos (kg)')),
              ButtonSegment(value: 'lb', label: Text('Libras (lb)')),
            ],
            selected: {user.unitPref},
            onSelectionChanged: (s) => appState.updateUnitPref(s.first),
          ),
          const SizedBox(height: 20),
          Text('Aparência', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', icon: Icon(Icons.smartphone_rounded), label: Text('Sistema')),
              ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
              ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
            ],
            selected: {user.themePref},
            onSelectionChanged: (s) => appState.updateThemePref(s.first),
          ),
        ],
      ),
    );

    final bodyCard = SumaCard(
      onTap: _editHeightAndGoal,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Altura e meta', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  user.heightCm != null ? '${user.heightCm!.toStringAsFixed(0)} cm' : 'Altura não definida',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (user.goalWeightKg != null)
                  Text(
                    'Meta: ${Units.formatWithUnit(user.goalWeightKg!, user.unitPref)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );

    final dataCard = SumaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: _exporting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined),
            title: const Text('Exportar meus dados (CSV)'),
            subtitle: const Text('Data, peso, gordura e hidratação'),
            onTap: _exporting ? null : _exportMyData,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Alterar senha'),
            onTap: _changePassword,
          ),
          if (user.isAdmin && widget.onOpenUsers != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Gerenciar usuários'),
              onTap: widget.onOpenUsers,
            ),
          ],
        ],
      ),
    );

    final cards = [
      profileCard,
      const SizedBox(height: 14),
      const SectionLabel('Preferências'),
      preferencesCard,
      const SizedBox(height: 14),
      bodyCard,
      const SizedBox(height: 22),
      const SectionLabel('Dados & conta'),
      dataCard,
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => appState.logout(),
        icon: Icon(Icons.logout, color: AppColors.negative),
        label: Text('Sair', style: TextStyle(color: AppColors.negative)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ResponsiveBody(
        child: wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [profileCard, const SizedBox(height: 14), bodyCard])),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionLabel('Preferências'), preferencesCard])),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Dados & conta'),
                  dataCard,
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: () => appState.logout(),
                        icon: Icon(Icons.logout, color: AppColors.negative),
                        label: Text('Sair', style: TextStyle(color: AppColors.negative)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative)),
                      ),
                    ),
                  ),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
      ),
    );
  }
}

class _ProfileEdit {
  final double heightCm;
  final double? goalWeightKg;
  const _ProfileEdit(this.heightCm, this.goalWeightKg);
}

class _EditProfileSheet extends StatefulWidget {
  final double heightCm;
  final double? goalWeightKg;
  final String unitPref;
  const _EditProfileSheet({required this.heightCm, required this.goalWeightKg, required this.unitPref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late double _heightCm = widget.heightCm;
  late bool _hasGoal = widget.goalWeightKg != null;
  late double _goalWeightKg = widget.goalWeightKg ?? widget.heightCm - 100;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Altura e meta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SumaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Altura', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: _heightCm.toStringAsFixed(0), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                          TextSpan(text: ' cm', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  Slider(value: _heightCm, min: 100, max: 230, onChanged: (v) => setState(() => _heightCm = v)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SumaCard(
              child: Row(
                children: [
                  Expanded(child: Text('Definir meta de peso', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  Switch(value: _hasGoal, onChanged: (v) => setState(() => _hasGoal = v)),
                ],
              ),
            ),
            if (_hasGoal) ...[
              const SizedBox(height: 14),
              StepperField(
                label: 'Peso desejado',
                value: Units.displayValue(_goalWeightKg, widget.unitPref),
                unit: Units.label(widget.unitPref),
                step: widget.unitPref == 'lb' ? 0.5 : 0.1,
                min: Units.displayValue(20, widget.unitPref),
                max: Units.displayValue(300, widget.unitPref),
                onChanged: (v) => setState(() => _goalWeightKg = Units.toKg(v, widget.unitPref)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ProfileEdit(_heightCm, _hasGoal ? _goalWeightKg : null)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
