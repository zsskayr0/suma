import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether QR *scanning* (camera) is available on this build. `mobile_scanner`
/// only ships Android/iOS/macOS/web implementations - Windows/Linux desktop
/// have no camera backend for it, so the scan button is hidden there.
/// Showing (generating) a QR code has no such restriction and works
/// everywhere via `qr_flutter`.
bool get qrScanSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
