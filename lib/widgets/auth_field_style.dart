import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A soft, muted blue used sparingly on the auth screens (focused field
/// borders) - the reference design is otherwise strictly black/white, so
/// this only shows up where some accent is actually needed for feedback.
const authPastelBlue = Color(0xFF8FBFEF);

/// Login/signup follow the *device's* light/dark setting (there's no
/// signed-in profile yet to carry an in-app preference) - true black in
/// dark mode, white in light mode, exactly like the reference.
bool isAuthDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color authPageColor(BuildContext context) => isAuthDark(context) ? Colors.black : Colors.white;

Color authBorderColor(BuildContext context) => isAuthDark(context) ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

Color authTextColor(BuildContext context) => isAuthDark(context) ? Colors.white : Colors.black;

Color authMutedTextColor(BuildContext context) => isAuthDark(context) ? Colors.white60 : Colors.black54;

/// The hairline-bordered field style shared by the login and signup forms.
InputDecoration authFieldDecoration(BuildContext context, {required String label, Widget? suffixIcon}) {
  final dark = isAuthDark(context);
  final base = dark ? Colors.white : Colors.black;
  OutlineInputBorder border(Color color, double width) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: width));
  return InputDecoration(
    hintText: label,
    hintStyle: TextStyle(color: base.withValues(alpha: 0.35), fontSize: 14.5),
    filled: true,
    fillColor: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(base.withValues(alpha: 0.12), 1),
    border: border(base.withValues(alpha: 0.12), 1),
    focusedBorder: border(authPastelBlue, 1.4),
    errorBorder: border(const Color(0xFFE5484D).withValues(alpha: 0.7), 1),
    focusedErrorBorder: border(const Color(0xFFE5484D), 1.4),
    errorStyle: const TextStyle(color: Color(0xFFE5484D), fontSize: 11.5),
  );
}

/// A field with its own label line above it, matching the reference (labels
/// sit outside the input, not floating inside it).
class AuthLabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool autocorrect;
  final Iterable<String>? autofillHints;

  const AuthLabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.autocorrect = true,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = authTextColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15),
          cursorColor: authPastelBlue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autocorrect: autocorrect,
          autofillHints: autofillHints,
          decoration: authFieldDecoration(context, label: hint, suffixIcon: suffixIcon),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}

/// The decorative-only Facebook/Google/Apple buttons - shown for visual
/// completeness, intentionally not wired to a real provider (Suma's
/// Supabase project isn't configured with OAuth), so tapping just says so.
/// Shown as a compact icon-only square (matching the reference's row of
/// three) rather than a labeled button - there isn't room for three full
/// "Continue with ..." buttons side by side.
class AuthSocialButton extends StatelessWidget {
  final AuthSocialProvider provider;
  const AuthSocialButton.facebook({super.key}) : provider = AuthSocialProvider.facebook;
  const AuthSocialButton.google({super.key}) : provider = AuthSocialProvider.google;
  const AuthSocialButton.apple({super.key}) : provider = AuthSocialProvider.apple;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (provider) {
      case AuthSocialProvider.facebook:
        icon = SvgPicture.asset('assets/icons/facebook_logo.svg', width: 20, height: 20);
        break;
      case AuthSocialProvider.google:
        icon = SvgPicture.asset('assets/icons/google_logo.svg', width: 20, height: 20);
        break;
      case AuthSocialProvider.apple:
        // Apple's logo is a single black/white glyph (no built-in tinting),
        // so pick the variant that reads correctly against the current
        // theme instead of colorFilter-ing a multi-tone mark.
        icon = SvgPicture.asset(isAuthDark(context) ? 'assets/icons/apple_logo_white.svg' : 'assets/icons/apple_logo_black.svg', width: 19, height: 19);
        break;
    }
    return OutlinedButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Em breve.'))),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: EdgeInsets.zero,
        side: BorderSide(color: authBorderColor(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: icon,
    );
  }
}

enum AuthSocialProvider { facebook, google, apple }

/// The pill-shaped Login/Register tab switcher at the top of the card -
/// the primary way to move between the two forms (the "Já tem conta?" /
/// "Não tem conta?" link at the bottom does the same thing, kept as a
/// secondary affordance since the reference shows both).
class AuthTabSwitcher extends StatelessWidget {
  final int index; // 0 = login, 1 = register
  final ValueChanged<int> onChanged;
  const AuthTabSwitcher({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = isAuthDark(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(context, 'Login', 0)),
          Expanded(child: _tab(context, 'Cadastro', 1)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, int i) {
    final selected = index == i;
    final dark = isAuthDark(context);
    return GestureDetector(
      onTap: () => onChanged(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? (dark ? const Color(0xFF1A1A1A) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: authTextColor(context),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// "Or" / "Or sign with" divider - [withLines] draws hairlines on either
/// side (signup's reference); without, it's just centered text (login's).
class AuthOrDivider extends StatelessWidget {
  final String text;
  final bool withLines;
  const AuthOrDivider({super.key, required this.text, this.withLines = true});

  @override
  Widget build(BuildContext context) {
    final line = Divider(color: authBorderColor(context), height: 1);
    final label = Text(text, style: TextStyle(color: authMutedTextColor(context), fontSize: 12.5));
    if (!withLines) return Center(child: label);
    return Row(
      children: [
        Expanded(child: line),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: label),
        Expanded(child: line),
      ],
    );
  }
}
