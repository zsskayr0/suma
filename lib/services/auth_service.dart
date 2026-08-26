import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local password hashing for Suma's predefined-login accounts.
///
/// This is NOT meant to defend a networked, multi-tenant server - Suma has
/// no backend. It exists so that a shared desktop/device with several local
/// accounts doesn't store or compare plain-text passwords. A random salt per
/// user plus a few thousand rounds of SHA-256 keeps it cheap (no native
/// dependency) while still being far from a single unsalted hash.
class AuthService {
  static const int _rounds = 120000;

  static String generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hashPassword(String password, String salt) {
    List<int> digest = utf8.encode('$salt:$password');
    for (var i = 0; i < _rounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  static bool verifyPassword(String password, String salt, String expectedHash) {
    final actual = hashPassword(password, salt);
    return _constantTimeEquals(actual, expectedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generates a readable random password (used only as a suggestion when
  /// creating a new managed account - never stored anywhere but shown once).
  static String generateRandomPassword({int length = 12}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
