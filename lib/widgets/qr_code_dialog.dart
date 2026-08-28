import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'suma_glass_sheet.dart';

/// Shows a family invite code as a scannable QR (plus the code itself as
/// text, for typing it in manually). Same floating flat+glass panel as the
/// register-entry menu - the QR itself still always sits on a plain white
/// tile regardless of app theme, since scanners need real light/dark module
/// contrast, not whatever happens to be the current dark-mode surface color.
Future<void> showInviteQrDialog(BuildContext context, {required String code, required String familyName}) {
  return showSumaGlassSheet<void>(
    context,
    maxWidth: 360,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(familyName, style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: code, version: QrVersions.auto, size: 240, gapless: false),
            ),
            const SizedBox(height: 16),
            Text(code, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4, color: scheme.onSurface)),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        ),
      );
    },
  );
}
