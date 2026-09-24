import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../services/settings_repository.dart';

class AdminProvider extends ChangeNotifier {
  static const _pinKey = 'admin_pin_hash';
  final _repo = SettingsRepository();
  bool isAdmin = false;
  bool loading = true;
  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;
  String? _pinHash;

  Future<void> load() async {
    _pinHash = await _repo.get(_pinKey);
    loading = false;
    notifyListeners();
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> setPin(String pin) async {
    if (pin.length < 4) return false;
    await _repo.set(_pinKey, _hash(pin));
    _pinHash = _hash(pin);
    isAdmin = true;
    notifyListeners();
    return true;
  }

  bool unlock(String pin) {
    if (_pinHash == null) return false;
    final ok = _hash(pin) == _pinHash;
    if (ok) {
      isAdmin = true;
      notifyListeners();
    }
    return ok;
  }

  void lock() {
    isAdmin = false;
    notifyListeners();
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!unlock(oldPin)) return false;
    if (newPin.length < 4) return false;
    await _repo.set(_pinKey, _hash(newPin));
    _pinHash = _hash(newPin);
    isAdmin = true;
    notifyListeners();
    return true;
  }
}
