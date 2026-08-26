import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/suma_mark.dart';

class _Slide {
  final HeroIcons icon;
  final String title;
  final String description;
  const _Slide({required this.icon, required this.title, required this.description});
}

const _slides = [
  _Slide(
    icon: HeroIcons.scale,
    title: 'Acompanhe seu peso',
    description: 'Registre peso, gordura corporal e hidratação, e veja sua evolução em gráficos simples e claros.',
  ),
  _Slide(
    icon: HeroIcons.userGroup,
    title: 'Junto com a família',
    description: 'Crie uma rede familiar ou entre com um código de convite, e acompanhem a jornada de todos, juntos.',
  ),
  _Slide(
    icon: HeroIcons.flag,
    title: 'Alcance suas metas',
    description: 'Defina uma meta de peso, veja o quanto falta e acompanhe seu IMC atualizado em tempo real.',
  ),
];

/// First-run explainer, shown once before the login/signup choice - a quick
/// tour of what Suma does, with dot pagination and a "Pular" escape hatch
/// for anyone who just wants to get to their account.
class AppIntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const AppIntroScreen({super.key, required this.onDone});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // A single muted glow tucked in the top-left corner, like a
          // distant sun - not a wash of blue across the whole screen - most
          // of the background stays true black.
          Positioned(
            top: -180,
            left: -160,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withValues(alpha: 0.5),
                    AppColors.deepBlue.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 520 : double.infinity),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(children: [SumaMark(size: 26)]),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _slides.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _page ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: i == _page ? AppColors.cyan : Colors.white24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            child: Text(_isLast ? 'Começar' : 'Próximo'),
                          ),
                          // Rigorously below the button, not tucked in the
                          // header - matches the reference exactly.
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              onPressed: widget.onDone,
                              style: TextButton.styleFrom(foregroundColor: Colors.white60),
                              child: const Text('Pular'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Center(child: HeroIcon(slide.icon, style: HeroIconStyle.outline, size: 44, color: Colors.white)),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 14.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
