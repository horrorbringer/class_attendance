import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/student/screens/student_dashboard_screen.dart';
import 'features/teacher/screens/teacher_classes_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SmartAttendanceApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Disables Android 12 rubber-band / stretching distortion on trackpad overscroll
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Resolves conflict with RefreshIndicator:
    // ClampingScrollPhysics prevents rubber-band / bounce collision with the pull-to-refresh spinner,
    // while AlwaysScrollableScrollPhysics ensures pull-to-refresh triggers even on short / empty lists.
    return const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _splashFinished = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildCurrentScreen(authState),
    );
  }

  Widget _buildCurrentScreen(AuthState authState) {
    // Show premium splash animation until both minimum splash sequence is done and session restored
    if (!_splashFinished || authState.isLoading) {
      return SplashScreen(
        key: const ValueKey('SplashScreen'),
        onFinished: () {
          if (mounted) {
            setState(() => _splashFinished = true);
          }
        },
      );
    }

    if (!authState.isAuthenticated) {
      return const LoginScreen(key: ValueKey('LoginScreen'));
    }

    if (authState.isTeacher) {
      return const TeacherClassesScreen(key: ValueKey('TeacherScreen'));
    }

    return const StudentDashboardScreen(key: ValueKey('StudentScreen'));
  }
}
