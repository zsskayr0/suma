import 'package:flutter/material.dart';

/// A soft, muted blue used sparingly on the auth screens (focused field
/// borders) - the reference design is otherwise strictly black/white, so
/// this only shows up where some accent is actually needed for feedback.
const authPastelBlue = Color(0xFF8FBFEF);

/// Login/signup follow the *device's* light/dark setting (there's no
/// signed-in profile yet to carry an in-app preference) - true black in
/// dark mode, white in light mode, exactly like the reference.
bool isAuthDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color authPageColor(BuildContext context) => isAuthDark(context) ? Colors.black : Colors.white;

Color authCardColor(BuildContext context) => isAuthDark(context) ? const Color(0xFF0A0A0A) : Colors.white;

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
          decoration: authFieldDecoration(context, label: hint, suffixIcon: suffixIcon),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}

/// The rounded, subtly-bordered card the login/signup form sits in - the
/// reference floats this as a distinct surface over the page background,
/// not just the form fields sitting directly on it.
class AuthCard extends StatelessWidget {
  final Widget child;
  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: authCardColor(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// The decorative-only "Continue with Google/Apple" buttons - shown for
/// visual completeness, intentionally not wired to a real provider (Suma's
/// Supabase project isn't configured with OAuth), so tapping just says so.
class AuthSocialButton extends StatelessWidget {
  final AuthSocialProvider provider;
  const AuthSocialButton.google({super.key}) : provider = AuthSocialProvider.google;
  const AuthSocialButton.apple({super.key}) : provider = AuthSocialProvider.apple;

  @override
  Widget build(BuildContext context) {
    final textColor = authTextColor(context);
    return OutlinedButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Em breve.'))),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: authBorderColor(context)),
        foregroundColor: textColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          provider == AuthSocialProvider.google
              ? const Icon(Icons.g_mobiledata_rounded, size: 26, color: Color(0xFF4285F4))
              : Icon(Icons.apple, size: 19, color: textColor),
          const SizedBox(width: 8),
          Text(provider == AuthSocialProvider.google ? 'Continuar com Google' : 'Continuar com Apple', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

enum AuthSocialProvider { google, apple }

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
