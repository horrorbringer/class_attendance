import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final bool noCredentialsSet;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.noCredentialsSet = false,
  });
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static String? lastErrorMessage;

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

  /// Authenticate using local biometrics with detailed error result
  static Future<BiometricAuthResult> authenticateDetailed({
    required String reason,
  }) async {
    lastErrorMessage = null;
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        lastErrorMessage = 'Biometric hardware is not available on this device.';
        return BiometricAuthResult(success: false, errorMessage: lastErrorMessage);
      }

      final success = await _auth.authenticate(
        localizedReason: reason,
      );

      if (!success) {
        lastErrorMessage = 'Biometric authentication cancelled.';
      }
      return BiometricAuthResult(success: success, errorMessage: lastErrorMessage);
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'noCredentialsSet' || e.code.contains('noCredentials') || e.code == 'PasscodeNotSet') {
        lastErrorMessage = 'No fingerprint or screen lock enrolled. Please set up a fingerprint or PIN in device Settings.';
        return BiometricAuthResult(success: false, noCredentialsSet: true, errorMessage: lastErrorMessage);
      } else if (e.code == 'NotAvailable') {
        lastErrorMessage = 'Biometrics is not available or disabled on this device.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        lastErrorMessage = 'Too many attempts. Biometrics temporarily locked.';
      } else {
        lastErrorMessage = e.message ?? 'Biometric verification cancelled or failed.';
      }
      return BiometricAuthResult(success: false, errorMessage: lastErrorMessage);
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      final str = e.toString();
      if (str.contains('noCredentialsSet')) {
        lastErrorMessage = 'No fingerprint or screen lock enrolled. Please set up a fingerprint or PIN in device Settings.';
        return BiometricAuthResult(success: false, noCredentialsSet: true, errorMessage: lastErrorMessage);
      }
      lastErrorMessage = 'Biometric verification error: $e';
      return BiometricAuthResult(success: false, errorMessage: lastErrorMessage);
    }
  }

  /// Authenticate using local biometrics (Face ID / Fingerprint)
  static Future<bool> authenticate({
    required String reason,
  }) async {
    final result = await authenticateDetailed(reason: reason);
    return result.success;
  }
}
