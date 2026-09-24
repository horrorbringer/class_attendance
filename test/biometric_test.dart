import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:class_attendance/core/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('StorageService Biometric Tests', () {
    test('isBiometricEnabled returns false by default for both roles', () async {
      expect(await StorageService.isBiometricEnabled('student'), isFalse);
      expect(await StorageService.isBiometricEnabled('teacher'), isFalse);
    });

    test('setBiometricEnabled updates preference for student and teacher independently', () async {
      await StorageService.setBiometricEnabled(true, 'student');
      expect(await StorageService.isBiometricEnabled('student'), isTrue);
      expect(await StorageService.isBiometricEnabled('teacher'), isFalse);

      await StorageService.setBiometricEnabled(true, 'teacher');
      expect(await StorageService.isBiometricEnabled('teacher'), isTrue);

      await StorageService.setBiometricEnabled(false, 'student');
      expect(await StorageService.isBiometricEnabled('student'), isFalse);
      expect(await StorageService.isBiometricEnabled('teacher'), isTrue);
    });

    test('saveBiometricCredentials and getBiometricCredentials store securely', () async {
      await StorageService.saveBiometricCredentials(
        username: 'student_dara',
        password: 'Password123!',
        role: 'student',
      );

      final creds = await StorageService.getBiometricCredentials('student');
      expect(creds, isNotNull);
      expect(creds!['username'], equals('student_dara'));
      expect(creds['password'], equals('Password123!'));

      // Teacher credentials should still be null
      expect(await StorageService.getBiometricCredentials('teacher'), isNull);
    });

    test('disabling biometric clears saved biometric credentials', () async {
      await StorageService.saveBiometricCredentials(
        username: 'teacher_sokha',
        password: 'TeacherPassword123!',
        role: 'teacher',
      );
      expect(await StorageService.getBiometricCredentials('teacher'), isNotNull);

      await StorageService.setBiometricEnabled(false, 'teacher');
      expect(await StorageService.getBiometricCredentials('teacher'), isNull);
    });

    test('clearSession clears token and session without wiping biometric vault', () async {
      await StorageService.saveSession(
        token: 'token_12345',
        role: 'student',
        userId: 42,
        username: 'student_dara',
      );
      await StorageService.setBiometricEnabled(true, 'student');
      await StorageService.saveBiometricCredentials(
        username: 'student_dara',
        password: 'Password123!',
        role: 'student',
      );

      await StorageService.clearSession();

      // Session token and role are gone
      expect(await StorageService.getToken(), isNull);
      expect(await StorageService.getRole(), isNull);

      // Biometric credentials remain intact for next biometric sign-in
      expect(await StorageService.isBiometricEnabled('student'), isTrue);
      final creds = await StorageService.getBiometricCredentials('student');
      expect(creds?['username'], equals('student_dara'));
    });
  });
}
