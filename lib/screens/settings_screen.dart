import 'dart:convert';
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../services/csv_export_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/height_units.dart';
import '../utils/qr_support.dart';
import '../utils/responsive.dart';
import '../utils/units.dart';
import '../widgets/goal_editor.dart';
import '../widgets/qr_code_dialog.dart';
import '../widgets/suma_glass_sheet.dart';
import '../widgets/suma_option_menu.dart';
import '../widgets/suma_time_picker.dart';
import '../widgets/suma_widgets.dart';
import '../widgets/theme_picker_menu.dart';
import 'qr_scan_screen.dart';

const _weekdayShort = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM']; // DateTime.weekday order, 1=Mon..7=Sun

const _readmeUrl = 'https://github.com/zsskayr0/suma#readme';
const _pullRequestsUrl = 'https://github.com/zsskayr0/suma/pulls';

/// "Perfil" tab: profile card, preferences (unit, theme, height, goal
/// weight), family network management, account actions (export, password)
/// and sign-out.
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
    final newPassword = await showSumaGlassSheet<String>(context, builder: (_) => const _ChangePasswordSheet());
    if (newPassword == null) return;
    if (!mounted) return;
    final error = await context.read<AppState>().changePassword(newPassword);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Senha atualizada.')));
  }

  Future<void> _pickAvatar() async {
    final appState = context.read<AppState>();
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final extension = (file.extension ?? 'jpg').toLowerCase();
    final error = await appState.updateAvatar(bytes: bytes, extension: extension);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _editName() async {
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final result = await showModalBottomSheet<_NameEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditNameSheet(firstName: user.firstName, lastName: user.lastName),
    );
    if (result == null) return;
    await appState.updateName(firstName: result.firstName, lastName: result.lastName);
  }

  Future<void> _editHeight() async {
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final result = await showSumaGlassSheet<_HeightEdit>(
      context,
      builder: (_) => _EditHeightSheet(heightCm: user.heightCm ?? 170, age: user.age ?? 30, sex: user.sex ?? 'unspecified', heightUnitPref: appState.heightUnitPref),
    );
    if (result == null) return;
    await appState.updateBodyProfile(heightCm: result.heightCm, age: result.age, sex: result.sex);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir $url')));
    }
  }

  Future<void> _pickWeightUnit(AppState appState) async {
    final result = await showSumaOptionMenu<String>(
      context,
      title: 'Unidade de peso',
      values: const ['kg', 'lb'],
      labels: const ['Quilos (kg)', 'Libras (lb)'],
      selected: appState.currentProfile!.unitPref,
    );
    if (result != null) await appState.updateUnitPref(result);
  }

  Future<void> _pickHeightUnit(AppState appState) async {
    final result = await showSumaOptionMenu<String>(
      context,
      title: 'Unidade de medida',
      values: const ['cm', 'in'],
      labels: const ['Centímetros (cm)', 'Polegadas (in)'],
      selected: appState.heightUnitPref,
    );
    if (result != null) await appState.updateHeightUnitPref(result);
  }

  Future<void> _pickTheme(AppState appState) async {
    // Each tap only nudges the cheap live-preview override (see
    // AppState.themePreviewOverride) - the real, persisted change happens
    // once here, after the sheet closes. Backdrop-dismiss (result == null)
    // just clears the preview, which reverts the visible theme back to
    // whatever was actually saved - a natural "cancel".
    final result = await showThemePickerMenu(
      context,
      selected: appState.themePref,
      onPreview: (mode) => appState.themePreviewOverride.value = mode,
    );
    appState.themePreviewOverride.value = null;
    if (result != null) await appState.updateThemePref(result);
  }

  Future<void> _editGoal() async {
    final appState = context.read<AppState>();
    final user = appState.currentProfile!;
    final currentWeightKg = appState.entries.isNotEmpty ? appState.entries.first.weightKg : null;
    final result = await showSumaGlassSheet<_GoalEdit>(
      context,
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

  Future<void> _editNotifications() async {
    final appState = context.read<AppState>();
    final result = await showSumaGlassSheet<_NotifEdit>(
      context,
      builder: (_) => _EditNotificationsSheet(
        enabled: appState.notifEnabled,
        days: appState.notifDays,
        hour: appState.notifHour,
        minute: appState.notifMinute,
      ),
    );
    if (result == null) return;
    if (result.enabled && Platform.isAndroid) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de notificação negada - ative em Ajustes do sistema para os lembretes funcionarem.')),
        );
      }
    }
    await appState.updateNotificationSettings(enabled: result.enabled, days: result.days, hour: result.hour, minute: result.minute);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: _pickAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(avatarUrl: user.avatarUrl, name: user.name, radius: 26, isAdmin: user.isAdmin),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface, width: 2),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(user.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _editName,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                Text(user.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                // Below the email, not squeezed into the same row as the name -
                // a long name + this pill side by side had no room to breathe.
                if (family != null) ...[
                  const SizedBox(height: 8),
                  Pill(text: user.isAdmin ? 'Admin da rede' : 'Membro', color: AppColors.roleRing(user.isAdmin)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final heightSummaryParts = [
      if (user.heightCm != null) HeightUnits.formatWithUnit(user.heightCm!, appState.heightUnitPref),
      if (user.age != null) '${user.age} anos',
      if (user.sex != null && user.sex != 'unspecified') (user.sex == 'male' ? 'Masculino' : 'Feminino'),
    ];
    final goalSummary = user.goalWeightKg != null
        ? '${user.goalIsLose ? 'Emagrecer até' : 'Ganhar peso até'} ${Units.formatWithUnit(user.goalWeightKg!, user.unitPref)}'
        : 'Nenhuma meta definida';
    final notifSummary = (appState.notifEnabled && appState.notifDays.isNotEmpty)
        ? '${(appState.notifDays.toList()..sort()).map((d) => _weekdayShort[d - 1]).join(' ')} às ${appState.notifHour.toString().padLeft(2, '0')}:${appState.notifMinute.toString().padLeft(2, '0')}'
        : 'Desativado';
    final themeLabel = switch (appState.themePref) { 'light' => 'Claro', 'dark' => 'Escuro', _ => 'Automático' };

    // Grouped, tappable rows (icon + title/subtitle + chevron) instead of
    // one standalone SumaCard per setting - reads as one list per section
    // rather than a stack of separate boxes.
    final accountCard = _SettingsGroup(
      rows: [
        _SettingsRow(icon: Icons.badge_outlined, title: 'Dados de perfil', subtitle: heightSummaryParts.isEmpty ? 'Não definido' : heightSummaryParts.join(' · '), onTap: _editHeight),
        _SettingsRow(icon: Icons.flag_outlined, title: 'Meta de peso', subtitle: goalSummary, onTap: _editGoal),
        _SettingsRow(icon: Icons.notifications_outlined, title: 'Notificações', subtitle: notifSummary, onTap: _editNotifications),
        _SettingsRow(icon: Icons.password_outlined, title: 'Alterar senha', onTap: _changePassword),
      ],
    );

    final preferencesCard = _SettingsGroup(
      rows: [
        _SettingsRow(icon: Icons.scale_outlined, title: 'Unidade de peso', value: user.unitPref == 'lb' ? 'Libras (lb)' : 'Quilos (kg)', onTap: () => _pickWeightUnit(appState)),
        _SettingsRow(icon: Icons.straighten_rounded, title: 'Unidade de medida', value: appState.heightUnitPref == 'in' ? 'Polegadas (in)' : 'Centímetros (cm)', onTap: () => _pickHeightUnit(appState)),
        _SettingsRow(icon: Icons.dark_mode_outlined, title: 'Tema', value: themeLabel, onTap: () => _pickTheme(appState)),
        _SettingsRow(icon: Icons.info_outline_rounded, title: 'Sobre nós', trailingIcon: Icons.open_in_new_rounded, onTap: () => _openUrl(_readmeUrl)),
      ],
    );

    final supportCard = _SettingsGroup(
      rows: [
        _SettingsRow(icon: Icons.help_outline_rounded, title: 'Ajuda', trailingIcon: Icons.open_in_new_rounded, onTap: () => _openUrl(_pullRequestsUrl)),
      ],
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
      // ListTile paints its ink splash on the nearest Material ancestor -
      // SumaCard's background is a plain DecoratedBox, so without this the
      // tap ripple on each row below is silently invisible.
      child: Material(
        color: Colors.transparent,
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
      const SizedBox(height: 22),
      const SectionLabel('Conta'),
      accountCard,
      const SizedBox(height: 22),
      const SectionLabel('Preferências'),
      preferencesCard,
      const SizedBox(height: 22),
      const SectionLabel('Suporte'),
      supportCard,
      const SizedBox(height: 22),
      const SectionLabel('Dados'),
      dataCard,
      const SizedBox(height: 24),
      signOutButton,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ResponsiveBody(
        child: wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [profileCard, const SizedBox(height: 14), familyCard, const SizedBox(height: 22), const SectionLabel('Conta'), accountCard])),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionLabel('Preferências'),
                            preferencesCard,
                            const SizedBox(height: 22),
                            const SectionLabel('Suporte'),
                            supportCard,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Dados'),
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

class _NotifEdit {
  final bool enabled;
  final Set<int> days;
  final int hour;
  final int minute;
  const _NotifEdit({required this.enabled, required this.days, required this.hour, required this.minute});
}

class _EditNotificationsSheet extends StatefulWidget {
  final bool enabled;
  final Set<int> days;
  final int hour;
  final int minute;
  const _EditNotificationsSheet({required this.enabled, required this.days, required this.hour, required this.minute});

  @override
  State<_EditNotificationsSheet> createState() => _EditNotificationsSheetState();
}

class _EditNotificationsSheetState extends State<_EditNotificationsSheet> {
  late bool _enabled = widget.enabled;
  late final Set<int> _days = {...widget.days};
  late int _hour = widget.hour;
  late int _minute = widget.minute;

  void _toggleDay(int weekday) {
    setState(() {
      if (_days.contains(weekday)) {
        if (_days.length > 1) _days.remove(weekday);
      } else {
        _days.add(weekday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Notificações', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Lembretes locais para registrar seu peso.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SumaCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lembrar de se pesar'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ),
            if (_enabled) ...[
              const SizedBox(height: 16),
              Text('Dias da semana', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (var weekday = 1; weekday <= 7; weekday++) _DayToggle(label: _weekdayShort[weekday - 1], selected: _days.contains(weekday), onTap: () => _toggleDay(weekday))],
              ),
              const SizedBox(height: 16),
              Text('Horário', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SumaTimePicker(
                hour: _hour,
                minute: _minute,
                onHourChanged: (v) => setState(() => _hour = v),
                onMinuteChanged: (v) => setState(() => _minute = v),
              ),
              if (Platform.isWindows) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Windows, esse lembrete só dispara enquanto o Suma estiver aberto. No Android ele funciona mesmo com o app fechado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_NotifEdit(enabled: _enabled, days: _days, hour: _hour, minute: _minute)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small round day-of-week toggle used for the reminder schedule - multiple
/// can be selected at once, unlike [_OptionRow] which is single-select.
class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primary : Colors.transparent,
          border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Text(
          label.substring(0, 1),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Replaces the old plain stock AlertDialog - a single obscured field with
/// no confirmation, no visibility toggle, no inline validation - with a
/// proper glass sheet matching the rest of the app: icon header, a
/// confirm-password field so a typo isn't discovered only after saving, a
/// show/hide toggle, and inline (not snackbar-after-the-fact) validation.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordCtrl.text;
    if (password.length < 6) {
      setState(() => _error = 'A senha deve ter ao menos 6 caracteres.');
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.lock_outline_rounded, color: scheme.primary, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            Text('Alterar senha', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Escolha uma nova senha para sua conta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              onChanged: (_) => _error == null ? null : setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Nova senha',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              onChanged: (_) => _error == null ? null : setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Alterar senha')),
          ],
        ),
      ),
    );
  }
}

class _HeightEdit {
  final double heightCm;
  final int age;
  final String sex;
  const _HeightEdit({required this.heightCm, required this.age, required this.sex});
}

class _EditHeightSheet extends StatefulWidget {
  final double heightCm;
  final int age;
  final String sex;
  final String heightUnitPref;
  const _EditHeightSheet({required this.heightCm, required this.age, required this.sex, required this.heightUnitPref});

  @override
  State<_EditHeightSheet> createState() => _EditHeightSheetState();
}

class _EditHeightSheetState extends State<_EditHeightSheet> {
  late double _heightCm = widget.heightCm;
  late int _age = widget.age;
  late String _sex = widget.sex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dados de perfil', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SumaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          // The slider itself still drags in cm (its range/
                          // step wouldn't make sense re-expressed in inches)
                          // - only the displayed number/unit follow the
                          // preference, same as weight's kg/lb does.
                          TextSpan(
                            text: HeightUnits.format(_heightCm, widget.heightUnitPref, decimals: widget.heightUnitPref == 'in' ? 1 : 0),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
                          ),
                          TextSpan(text: ' ${HeightUnits.label(widget.heightUnitPref)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  Slider(value: _heightCm, min: 100, max: 230, onChanged: (v) => setState(() => _heightCm = v)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            StepperField(
              label: 'Idade',
              value: _age.toDouble(),
              unit: 'anos',
              step: 1,
              min: 1,
              max: 120,
              decimals: 0,
              onChanged: (v) => setState(() => _age = v.round()),
            ),
            const SizedBox(height: 16),
            Text('Sexo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            // Plain (unsuffixed) glyphs, not _rounded - those live at newer,
            // higher codepoints this bundled icon font doesn't actually
            // have (same issue monitor_weight_outlined had: it renders
            // blank, not missing-at-compile-time, so nothing catches it
            // except actually looking at the screen).
            _OptionRow(icon: Icons.male, label: 'Masculino', value: 'male', selected: _sex, onSelected: (v) => setState(() => _sex = v)),
            const SizedBox(height: 8),
            _OptionRow(icon: Icons.female, label: 'Feminino', value: 'female', selected: _sex, onSelected: (v) => setState(() => _sex = v)),
            const SizedBox(height: 8),
            _OptionRow(icon: Icons.person_outline_rounded, label: 'Prefiro não informar', value: 'unspecified', selected: _sex, onSelected: (v) => setState(() => _sex = v)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_HeightEdit(heightCm: _heightCm, age: _age, sex: _sex)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameEdit {
  final String firstName;
  final String lastName;
  const _NameEdit({required this.firstName, required this.lastName});
}

class _EditNameSheet extends StatefulWidget {
  final String firstName;
  final String lastName;
  const _EditNameSheet({required this.firstName, required this.lastName});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final _firstCtrl = TextEditingController(text: widget.firstName);
  late final _lastCtrl = TextEditingController(text: widget.lastName);

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nome', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _firstCtrl, decoration: const InputDecoration(labelText: 'Nome'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          TextField(controller: _lastCtrl, decoration: const InputDecoration(labelText: 'Sobrenome'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_NameEdit(firstName: _firstCtrl.text.trim(), lastName: _lastCtrl.text.trim())),
            child: const Text('Salvar'),
          ),
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

/// A titled group of tappable [_SettingsRow]s sharing one card - "Conta",
/// "Preferências" and "Suporte" each render as one of these instead of a
/// stack of separate standalone cards, mirroring a typical iOS/Android
/// settings screen's grouped list.
class _SettingsGroup extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SumaCard(
      padding: EdgeInsets.zero,
      // Same reasoning as dataCard below: ListTile paints its ink splash on
      // the nearest Material ancestor, and SumaCard's own background is a
      // plain DecoratedBox - without this the tap ripple is invisible.
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle; // shown below the title, e.g. a summary
  final String? value; // shown inline before the trailing icon, e.g. "kg"
  final IconData trailingIcon;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailingIcon = Icons.chevron_right_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(value!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
          ],
          Icon(trailingIcon, color: scheme.onSurfaceVariant, size: trailingIcon == Icons.chevron_right_rounded ? 24 : 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// A full-width tappable option row instead of a segment sharing horizontal
/// space with the others - used for "Aparência" (Sistema/Claro/Escuro) and
/// "Sexo" (Masculino/Feminino/Prefiro não informar).
class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _OptionRow({required this.icon, required this.label, required this.value, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? scheme.primary : scheme.onSurface),
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
