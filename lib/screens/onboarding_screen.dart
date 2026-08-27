import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../state/app_state.dart';
import '../utils/bmi.dart';
import '../utils/qr_support.dart';
import '../utils/units.dart';
import '../widgets/goal_editor.dart';
import '../widgets/suma_widgets.dart';
import 'qr_scan_screen.dart';

/// One-time setup wizard shown right after an account's first sign-in.
/// Starts with the "rede familiar" choice (only if the account isn't
/// already in a family - e.g. it was just created), then walks through
/// preferred unit, height, starting weight, optional goal weight and
/// light/dark preference. Finishing it logs the very first entry so the
/// dashboard never opens empty-handed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  late final bool _showFamilyPage;
  late final int _pageCount;

  String _unitPref = 'kg';
  double _heightCm = 170;
  double _weightKg = 70;
  bool _hasGoal = false;
  double _goalWeightKg = 65;
  String _goalType = 'lose';
  String _themePref = 'system';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _showFamilyPage = context.read<AppState>().currentProfile?.familyId == null;
    _pageCount = _showFamilyPage ? 5 : 4;
    _themePref = context.read<AppState>().themePref;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _back() {
    _pageController.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  /// Applies the theme choice live (same as Ajustes does after onboarding)
  /// instead of only saving it silently for when [_finish] runs - otherwise
  /// picking "Claro" here has no visible effect until the wizard is done.
  void _onThemeChanged(String pref) {
    setState(() => _themePref = pref);
    context.read<AppState>().updateThemePref(pref);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await context.read<AppState>().completeOnboarding(
          heightCm: _heightCm,
          initialWeightKg: _weightKg,
          goalWeightKg: _hasGoal ? _goalWeightKg : null,
          goalType: _goalType,
          unitPref: _unitPref,
          themePref: _themePref,
        );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_ios_new_rounded), iconSize: 18)
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Row(
                        children: List.generate(_pageCount, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      if (_showFamilyPage) const _FamilyPage(),
                      _UnitPage(unitPref: _unitPref, onChanged: (v) => setState(() => _unitPref = v)),
                      _HeightWeightPage(
                        unitPref: _unitPref,
                        heightCm: _heightCm,
                        weightKg: _weightKg,
                        onHeightChanged: (v) => setState(() => _heightCm = v),
                        onWeightChanged: (v) => setState(() => _weightKg = v),
                      ),
                      _GoalPage(
                        unitPref: _unitPref,
                        heightCm: _heightCm,
                        hasGoal: _hasGoal,
                        goalType: _goalType,
                        goalWeightKg: _goalWeightKg,
                        currentWeightKg: _weightKg,
                        onToggle: (v) => setState(() => _hasGoal = v),
                        onGoalTypeChanged: (v) => setState(() => _goalType = v),
                        onGoalChanged: (v) => setState(() => _goalWeightKg = v),
                      ),
                      _ThemePage(themePref: _themePref, onChanged: _onThemeChanged),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: FilledButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_page == _pageCount - 1 ? 'Concluir' : 'Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingScaffold({required this.icon, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: scheme.primary, size: 30),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

enum _FamilyAction { none, create, join }

/// First wizard page (only shown when the account isn't in a family yet):
/// create a brand-new "rede familiar" or join one via invite code. Neither
/// is required - the outer wizard's own "Continuar" moves on regardless,
/// and both choices stay available later from Ajustes.
class _FamilyPage extends StatefulWidget {
  const _FamilyPage();

  @override
  State<_FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<_FamilyPage> {
  _FamilyAction _action = _FamilyAction.none;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _createdCode;
  bool _joined = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    if (e is PostgrestException) return e.message;
    return 'Não foi possível concluir. Verifique sua conexão e tente novamente.';
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Dê um nome para sua rede.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final code = await context.read<AppState>().createFamily(_nameCtrl.text);
      if (!mounted) return;
      setState(() {
        _createdCode = code;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _submitting = false;
      });
    }
  }

  Future<void> _join() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Informe o código de convite.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AppState>().joinFamily(_codeCtrl.text);
      if (!mounted) return;
      setState(() {
        _joined = true;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _submitting = false;
      });
    }
  }

  Widget _spinner() => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_createdCode != null) {
      return _OnboardingScaffold(
        icon: Icons.groups_rounded,
        title: 'Rede criada!',
        subtitle: 'Compartilhe este código com sua família - qualquer pessoa pode usá-lo para entrar na sua rede ao criar a própria conta.',
        child: SumaCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(data: _createdCode!, version: QrVersions.auto, size: 200, gapless: false),
              ),
              const SizedBox(height: 14),
              Text(_createdCode!, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _createdCode!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado.')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar código'),
              ),
            ],
          ),
        ),
      );
    }

    if (_joined) {
      return _OnboardingScaffold(
        icon: Icons.groups_rounded,
        title: 'Tudo certo!',
        subtitle: 'Você entrou na rede familiar. O administrador dela poderá acompanhar seu progresso.',
        child: const SizedBox.shrink(),
      );
    }

    return _OnboardingScaffold(
      icon: Icons.groups_rounded,
      title: 'Rede familiar',
      subtitle: 'Crie sua própria rede ou entre em uma já existente da sua família. Pode pular e decidir depois em Ajustes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FamilyActionCard(
            icon: Icons.add_home_rounded,
            title: 'Criar minha rede',
            expanded: _action == _FamilyAction.create,
            onTap: () => setState(() => _action = _action == _FamilyAction.create ? _FamilyAction.none : _FamilyAction.create),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome da rede (ex: Família Silva)')),
                const SizedBox(height: 10),
                FilledButton(onPressed: _submitting ? null : _create, child: _submitting ? _spinner() : const Text('Criar')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FamilyActionCard(
            icon: Icons.qr_code_rounded,
            title: 'Entrar com código de convite',
            expanded: _action == _FamilyAction.join,
            onTap: () => setState(() => _action = _action == _FamilyAction.join ? _FamilyAction.none : _FamilyAction.join),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Código de convite',
                    suffixIcon: qrScanSupported
                        ? IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            tooltip: 'Escanear QR code',
                            onPressed: () async {
                              final scanned = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
                              if (scanned != null) _codeCtrl.text = scanned;
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _submitting ? null : _join, child: _submitting ? _spinner() : const Text('Entrar')),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}

class _FamilyActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _FamilyActionCard({required this.icon, required this.title, required this.expanded, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(padding: const EdgeInsets.only(top: 14), child: child),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _UnitPage extends StatelessWidget {
  final String unitPref;
  final ValueChanged<String> onChanged;
  const _UnitPage({required this.unitPref, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.straighten_rounded,
      title: 'Unidade de peso',
      subtitle: 'Qual unidade você prefere usar para acompanhar seu peso?',
      child: Row(
        children: [
          Expanded(child: _UnitCard(label: 'Quilos', suffix: 'kg', selected: unitPref == 'kg', onTap: () => onChanged('kg'))),
          const SizedBox(width: 12),
          Expanded(child: _UnitCard(label: 'Libras', suffix: 'lb', selected: unitPref == 'lb', onTap: () => onChanged('lb'))),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final String label;
  final String suffix;
  final bool selected;
  final VoidCallback onTap;
  const _UnitCard({required this.label, required this.suffix, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.14) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(suffix, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: selected ? scheme.primary : scheme.onSurface)),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _HeightWeightPage extends StatelessWidget {
  final String unitPref;
  final double heightCm;
  final double weightKg;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onWeightChanged;

  const _HeightWeightPage({
    required this.unitPref,
    required this.heightCm,
    required this.weightKg,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bmi = Bmi.calculate(weightKg: weightKg, heightCm: heightCm);

    return _OnboardingScaffold(
      icon: Icons.height_rounded,
      title: 'Altura e peso atual',
      subtitle: 'Usamos isso para calcular seu IMC em tempo real no painel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Altura', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: heightCm.toStringAsFixed(0), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                        TextSpan(text: ' cm', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 6, overlayShape: SliderComponentShape.noOverlay),
                  child: Slider(
                    value: heightCm,
                    min: 100,
                    max: 230,
                    onChanged: onHeightChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('100 cm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text('230 cm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StepperField(
            label: 'Peso atual',
            value: Units.displayValue(weightKg, unitPref),
            unit: Units.label(unitPref),
            step: unitPref == 'lb' ? 0.5 : 0.1,
            min: Units.displayValue(20, unitPref),
            max: Units.displayValue(300, unitPref),
            onChanged: (v) => onWeightChanged(Units.toKg(v, unitPref)),
          ),
          const SizedBox(height: 14),
          if (bmi != null)
            SumaCard(
              child: Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, color: Bmi.color(bmi)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMC em tempo real', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        Text(bmi.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Pill(text: Bmi.category(bmi), color: Bmi.color(bmi)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final String unitPref;
  final double? heightCm;
  final bool hasGoal;
  final String goalType;
  final double goalWeightKg;
  final double currentWeightKg;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onGoalTypeChanged;
  final ValueChanged<double> onGoalChanged;

  const _GoalPage({
    required this.unitPref,
    required this.heightCm,
    required this.hasGoal,
    required this.goalType,
    required this.goalWeightKg,
    required this.currentWeightKg,
    required this.onToggle,
    required this.onGoalTypeChanged,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OnboardingScaffold(
      icon: Icons.flag_outlined,
      title: 'Meta de peso',
      subtitle: 'Opcional - defina um objetivo para acompanhar seu progresso no painel. Pode pular e decidir depois em Ajustes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Peso atual: ${Units.formatWithUnit(currentWeightKg, unitPref)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          GoalEditor(
            hasGoal: hasGoal,
            onHasGoalChanged: onToggle,
            goalType: goalType,
            onGoalTypeChanged: onGoalTypeChanged,
            goalWeightKg: goalWeightKg,
            onGoalWeightChanged: onGoalChanged,
            currentWeightKg: currentWeightKg,
            heightCm: heightCm,
            unitPref: unitPref,
          ),
        ],
      ),
    );
  }
}

class _ThemePage extends StatelessWidget {
  final String themePref;
  final ValueChanged<String> onChanged;
  const _ThemePage({required this.themePref, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.dark_mode_outlined,
      title: 'Aparência',
      subtitle: 'Escolha como o Suma deve aparecer para você. Dá para trocar depois em Ajustes.',
      child: Column(
        children: [
          _ThemeOption(
            icon: Icons.smartphone_rounded,
            label: 'Igual ao sistema',
            selected: themePref == 'system',
            onTap: () => onChanged('system'),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            icon: Icons.light_mode_outlined,
            label: 'Claro',
            selected: themePref == 'light',
            onTap: () => onChanged('light'),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            icon: Icons.dark_mode_outlined,
            label: 'Escuro',
            selected: themePref == 'dark',
            onTap: () => onChanged('dark'),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SumaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary) else Icon(Icons.circle_outlined, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
