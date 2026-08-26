import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/qr_support.dart';
import '../utils/responsive.dart';
import '../utils/units.dart';
import '../widgets/goal_editor.dart';
import '../widgets/qr_code_dialog.dart';
import '../widgets/suma_widgets.dart';
import 'qr_scan_screen.dart';

/// "Ajustes" tab: preferences (unit, theme, height, goal weight), family
/// network management, account actions (export, password) and sign-out.
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenUsers;

  const SettingsScreen({super.key, this.onOpenUsers});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;
  bool _familyBusy = false;

  Future<void> _exportMyData() async {
    setState(() => _exporting = true);
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final file = await CsvExportService.exportAndHandOff(user, appState.entries);
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV salvo em: ${file.path}')));
  }

  Future<void> _importData() async {
    final appState = context.read<AppState>();
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
    if (file == null) return;

    String content;
    try {
      final bytes = await file.readAsBytes();
      content = utf8.decode(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O arquivo não parece ser um CSV de texto válido.')));
      return;
    }

    final parsed = CsvExportService.parseCsv(content, appState.currentProfile!.id);
    if (parsed.entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum registro válido encontrado no arquivo.')));
      return;
    }

    setState(() => _importing = true);
    await appState.importEntries(parsed.entries);
    if (!mounted) return;
    setState(() => _importing = false);
    final summary = parsed.skipped > 0
        ? '${parsed.entries.length} registro(s) importado(s) · ${parsed.skipped} linha(s) ignorada(s).'
        : '${parsed.entries.length} registro(s) importado(s).';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
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
    final error = await context.read<AppState>().changePassword(newPassword);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Senha atualizada.')));
  }

  Future<void> _editHeight() async {
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditHeightSheet(heightCm: user.heightCm ?? 170),
    );
    if (result == null) return;
    await appState.updateHeight(result);
  }

  Future<void> _editGoal() async {
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final currentWeightKg = appState.entries.isNotEmpty ? appState.entries.first.weightKg : null;
    final result = await showModalBottomSheet<_GoalEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditGoalSheet(
        hasGoal: user.goalWeightKg != null,
        goalType: user.goalType,
        goalWeightKg: user.goalWeightKg ?? (currentWeightKg ?? 70) - 5,
        currentWeightKg: currentWeightKg,
        heightCm: user.heightCm,
        unitPref: user.unitPref,
      ),
    );
    if (result == null) return;
    await appState.updateGoal(goalWeightKg: result.hasGoal ? result.goalWeightKg : null, goalType: result.goalType, clearGoal: !result.hasGoal);
  }

  Future<void> _createFamily() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar rede familiar'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome da rede (ex: Família Silva)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Criar')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _familyBusy = true);
    try {
      final code = await appState.createFamily(name);
      if (!mounted) return;
      await showInviteQrDialog(context, code: code, familyName: 'Rede criada! Compartilhe este código ou QR code.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _familyBusy = false);
    }
  }

  Future<void> _joinFamily() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar com código de convite'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Código de convite',
            suffixIcon: qrScanSupported
                ? IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'Escanear QR code',
                    onPressed: () async {
                      final scanned = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
                      if (scanned != null) controller.text = scanned;
                    },
                  )
                : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Entrar')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() => _familyBusy = true);
    try {
      await appState.joinFamily(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você entrou na rede familiar.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _familyBusy = false);
    }
  }

  Future<void> _leaveFamily() async {
    final appState = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da rede familiar?'),
        content: const Text('Seus próprios dados continuam com você - só deixa de fazer parte dessa rede.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _familyBusy = true);
    final error = await appState.leaveFamily();
    if (!mounted) return;
    setState(() => _familyBusy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    return 'Não foi possível concluir. Verifique sua conexão e tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentProfile!;
    final family = appState.currentFamily;
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
                Text(user.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (family != null) Pill(text: user.isAdmin ? 'Admin da rede' : 'Membro', color: user.isAdmin ? AppColors.goalAccent : Theme.of(context).colorScheme.primary),
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

    final heightCard = SumaCard(
      onTap: _editHeight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Altura', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  user.heightCm != null ? '${user.heightCm!.toStringAsFixed(0)} cm' : 'Não definida',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );

    final goalCard = SumaCard(
      onTap: _editGoal,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meta de peso', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (user.goalWeightKg != null)
                  Text(
                    '${user.goalIsLose ? 'Emagrecer até' : 'Ganhar peso até'} ${Units.formatWithUnit(user.goalWeightKg!, user.unitPref)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                else
                  Text('Nenhuma meta definida', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );

    final familyCard = SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text('Rede familiar', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 12),
          if (family == null) ...[
            Text(
              'Você ainda não faz parte de uma rede familiar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _familyBusy ? null : _createFamily, child: const Text('Criar rede'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: _familyBusy ? null : _joinFamily, child: const Text('Entrar com código'))),
              ],
            ),
          ] else ...[
            Text(family.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (user.isAdmin)
              Row(
                children: [
                  Text('Código: ${family.inviteCode}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copiar código',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: family.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado.')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    tooltip: 'Mostrar QR code',
                    onPressed: () => showInviteQrDialog(context, code: family.inviteCode, familyName: family.name),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _familyBusy ? null : _leaveFamily,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative), foregroundColor: AppColors.negative),
              child: const Text('Sair da rede'),
            ),
          ],
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
            leading: _importing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_upload_outlined),
            title: const Text('Importar dados (CSV)'),
            subtitle: const Text('Adiciona ao seu histórico - mesmo formato da exportação'),
            onTap: _importing ? null : _importData,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Alterar senha'),
            onTap: _changePassword,
          ),
          if (user.isAdmin && family != null && widget.onOpenUsers != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Ver membros da rede'),
              onTap: widget.onOpenUsers,
            ),
          ],
        ],
      ),
    );

    final signOutButton = OutlinedButton.icon(
      onPressed: () => appState.signOut(),
      icon: Icon(Icons.logout, color: AppColors.negative),
      label: Text('Sair', style: TextStyle(color: AppColors.negative)),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative)),
    );

    final cards = [
      profileCard,
      const SizedBox(height: 14),
      familyCard,
      const SizedBox(height: 14),
      const SectionLabel('Preferências'),
      preferencesCard,
      const SizedBox(height: 14),
      heightCard,
      const SizedBox(height: 14),
      goalCard,
      const SizedBox(height: 22),
      const SectionLabel('Dados & conta'),
      dataCard,
      const SizedBox(height: 24),
      signOutButton,
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
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [profileCard, const SizedBox(height: 14), familyCard, const SizedBox(height: 14), heightCard, const SizedBox(height: 14), goalCard])),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionLabel('Preferências'), preferencesCard])),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Dados & conta'),
                  dataCard,
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerLeft, child: SizedBox(width: 220, child: signOutButton)),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
      ),
    );
  }
}

class _EditHeightSheet extends StatefulWidget {
  final double heightCm;
  const _EditHeightSheet({required this.heightCm});

  @override
  State<_EditHeightSheet> createState() => _EditHeightSheetState();
}

class _EditHeightSheetState extends State<_EditHeightSheet> {
  late double _heightCm = widget.heightCm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Altura', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(context).pop(_heightCm), child: const Text('Salvar')),
        ],
      ),
    );
  }
}

class _GoalEdit {
  final bool hasGoal;
  final String goalType;
  final double goalWeightKg;
  const _GoalEdit({required this.hasGoal, required this.goalType, required this.goalWeightKg});
}

class _EditGoalSheet extends StatefulWidget {
  final bool hasGoal;
  final String goalType;
  final double goalWeightKg;
  final double? currentWeightKg;
  final double? heightCm;
  final String unitPref;

  const _EditGoalSheet({
    required this.hasGoal,
    required this.goalType,
    required this.goalWeightKg,
    required this.currentWeightKg,
    required this.heightCm,
    required this.unitPref,
  });

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  late bool _hasGoal = widget.hasGoal;
  late String _goalType = widget.goalType;
  late double _goalWeightKg = widget.goalWeightKg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Meta de peso', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            GoalEditor(
              hasGoal: _hasGoal,
              onHasGoalChanged: (v) => setState(() => _hasGoal = v),
              goalType: _goalType,
              onGoalTypeChanged: (v) => setState(() => _goalType = v),
              goalWeightKg: _goalWeightKg,
              onGoalWeightChanged: (v) => setState(() => _goalWeightKg = v),
              currentWeightKg: widget.currentWeightKg,
              heightCm: widget.heightCm,
              unitPref: widget.unitPref,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_GoalEdit(hasGoal: _hasGoal, goalType: _goalType, goalWeightKg: _goalWeightKg)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
