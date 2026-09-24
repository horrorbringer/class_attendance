import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isTeacherPortal = false;
  String _biometricLabel = 'Biometrics';
  bool _isAuthenticatingBiometrics = false;
  bool _hasBiometricReady = false;
  bool _showDemoAccounts = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _usernameController.addListener(() => setState(() {}));
  }

  Future<void> _checkBiometricAvailability() async {
    final label = await BiometricService.getBiometricLabel();
    final role = _isTeacherPortal ? 'teacher' : 'student';
    final isEnabled = await StorageService.isBiometricEnabled(role);
    final creds = await StorageService.getBiometricCredentials(role);
    final lastCreds = await StorageService.getLastKnownCredentials(role);

    if (mounted) {
      setState(() {
        _biometricLabel = label;
        _hasBiometricReady = isEnabled && (creds != null || lastCreds != null);
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillCredentials(String username, String password) {
    HapticFeedback.lightImpact();
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
  }

  Future<void> _handleBiometricLogin() async {
    HapticFeedback.mediumImpact();
    final role = _isTeacherPortal ? 'teacher' : 'student';
    final creds = await StorageService.getBiometricCredentials(role);
    final lastCreds = await StorageService.getLastKnownCredentials(role);

    if (creds == null && lastCreds == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No biometric credentials saved. Log in once with password, then enable $_biometricLabel in Profile Settings.',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() => _isAuthenticatingBiometrics = true);
    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Verify your $_biometricLabel to sign in as ${_isTeacherPortal ? 'Faculty' : 'Student'}',
      );

      if (!authenticated) {
        if (mounted) {
          setState(() => _isAuthenticatingBiometrics = false);
          final err = BiometricService.lastErrorMessage;
          if (err != null && !err.toLowerCase().contains('cancelled')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.absent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
        return;
      }

      final activeCreds = creds ?? lastCreds!;
      _usernameController.text = activeCreds['username']!;
      _passwordController.text = activeCreds['password']!;

      final success = await ref.read(authProvider.notifier).login(
            activeCreds['username']!,
            activeCreds['password']!,
          );

      if (!success && mounted) {
        final error = ref.read(authProvider).errorMessage ?? 'Biometric login failed. Please sign in with password.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.absent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometrics = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Invalid credentials. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.absent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Reset Password',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isTeacherPortal
                  ? 'Faculty password resets must be authorized by your academic department administrator or institutional IT desk.'
                  : 'Student credentials are tied to your official University Single Sign-On. Please reach out to student services or visit your campus registrar.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Helpdesk: support@campus.edu\nPhone: (+855) 23 880 880',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Understood',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background ambient decoration
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    const Color(0xFF3B82F6).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.06),
                    const Color(0xFF10B981).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Area
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sliding Role Selector
                        _buildRoleSelector(),

                        const SizedBox(height: 22),

                        // App Logo & Header Section
                        _buildHeader(),

                        const SizedBox(height: 22),

                        // Form Card
                        _buildFormCard(authState),

                        const SizedBox(height: 16),

                        // SSO Option (for students)
                        if (!_isTeacherPortal) ...[
                          _buildSsoOption(),
                          const SizedBox(height: 16),
                        ],

                        // Quick Demo Accounts Tray
                        _buildDemoAccountsTray(),

                        const SizedBox(height: 18),

                        // Connection Status Footer
                        _buildFooterStatus(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Subcomponents ---

  Widget _buildRoleSelector() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleTab(
              label: 'Student',
              icon: Icons.school_outlined,
              isSelected: !_isTeacherPortal,
              onTap: () {
                if (_isTeacherPortal) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isTeacherPortal = false;
                    _usernameController.clear();
                    _passwordController.clear();
                  });
                  _checkBiometricAvailability();
                }
              },
            ),
            _buildRoleTab(
              label: 'Faculty / Staff',
              icon: Icons.shield_outlined,
              isSelected: _isTeacherPortal,
              onTap: () {
                if (!_isTeacherPortal) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isTeacherPortal = true;
                    _usernameController.clear();
                    _passwordController.clear();
                  });
                  _checkBiometricAvailability();
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildRoleTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Emblem
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Center(
                child: Icon(
                  _isTeacherPortal ? Icons.verified_user_rounded : Icons.school_rounded,
                  size: 30,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 14),

        // Title
        Text(
          'Smart Attendance',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 4),

        // Subtitle
        Text(
          _isTeacherPortal
              ? 'Faculty Portal • Academic & Class Management'
              : 'Sign in to access your student attendance & schedule',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildFormCard(AuthState authState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username / ID Label
          Text(
            _isTeacherPortal ? 'Teacher Email or Staff ID' : 'Student ID or Email',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),

          // Username Field
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              hintText: _isTeacherPortal ? 'emily.okonkwo@school.edu' : 'sarah.johnson@university.edu',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 19),
              suffixIcon: _usernameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () => _usernameController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your username or ID' : null,
          ),

          const SizedBox(height: 16),

          // Password Label & Forgot Password Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: _showForgotPasswordDialog,
                child: Text(
                  'Forgot?',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              hintText: '••••••••••••',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 19),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF64748B),
                  size: 19,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your password' : null,
          ),

          const SizedBox(height: 20),

          // Primary Sign In Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isTeacherPortal ? 'Sign in to Faculty Portal' : 'Sign in as Student',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Biometric Button
          SizedBox(
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _hasBiometricReady ? const Color(0xFFF0FDF4) : Colors.transparent,
                side: BorderSide(
                  color: _hasBiometricReady ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isAuthenticatingBiometrics || authState.isLoading ? null : _handleBiometricLogin,
              child: _isAuthenticatingBiometrics
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verifying $_biometricLabel...',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _biometricLabel.contains('Face') ? Icons.face_rounded : Icons.fingerprint_rounded,
                          size: 19,
                          color: _hasBiometricReady ? const Color(0xFF16A34A) : const Color(0xFF334155),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in with $_biometricLabel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _hasBiometricReady ? const Color(0xFF15803D) : const Color(0xFF334155),
                          ),
                        ),
                        if (_hasBiometricReady) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildSsoOption() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Campus Single Sign-On (SSO) gateway opened.',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_outlined, size: 17, color: Color(0xFF334155)),
          const SizedBox(width: 8),
          Text(
            'Sign in with Campus SSO',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildDemoAccountsTray() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showDemoAccounts = !_showDemoAccounts);
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFEAB308)),
                    const SizedBox(width: 5),
                    Text(
                      _isTeacherPortal ? 'Faculty Demo Accounts' : 'Student Demo Accounts',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showDemoAccounts ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          if (_showDemoAccounts) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _isTeacherPortal
                  ? [
                      _buildQuickDemoChip('👨‍🏫 Dr. Sokha', 'teacher_sokha', 'TeacherPassword123!'),
                      _buildQuickDemoChip('👩‍🏫 Dr. Vanny', 'teacher_vanny', 'TeacherPassword123!'),
                    ]
                  : [
                      _buildQuickDemoChip('🎓 Dara', 'student_dara', 'StudentPassword123!'),
                      _buildQuickDemoChip('🎓 Bopha', 'student_bopha', 'StudentPassword123!'),
                    ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildQuickDemoChip(String label, String username, String password) {
    return InkWell(
      onTap: () => _fillCredentials(username, password),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterStatus() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.present,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Secure Campus Cloud • student-attendance.vanny.monster',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
