import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a family invite code as a scannable QR (plus the code itself as
/// text, for typing it in manually). Always rendered on a white card
/// regardless of app theme - QR scanners need real light/dark module
/// contrast, not whatever happens to be the current dark-mode surface color.
Future<void> showInviteQrDialog(BuildContext context, {required String code, required String familyName}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(familyName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: code, version: QrVersions.auto, size: 220, gapless: false),
          ),
          const SizedBox(height: 14),
          Text(code, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4)),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
    ),
  );
}
