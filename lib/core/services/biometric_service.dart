import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device has biometric hardware capable of checking biometrics
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('[BiometricService] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Check if there are enrolled biometrics on device
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricService] hasEnrolledBiometrics error: $e');
      return false;
    }
  }

  /// Get list of available biometric types (e.g. face, fingerprint)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Get user-friendly name of the primary biometric sensor
  static Future<String> getBiometricLabel() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris Scanner';
      }
    } catch (_) {}
    return 'Biometrics';
  }

  /// Authenticate using local biometrics (Face ID / Fingerprint)
  static Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('[BiometricService] Biometrics not available on this device');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
