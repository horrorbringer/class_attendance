import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillCredentials(String username, String password) {
    _usernameController.text = username;
    _passwordController.text = password;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
          _usernameController.text,
          _passwordController.text,
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.absent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Portal Role Selector Pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isTeacherPortal = false;
                                _usernameController.clear();
                                _passwordController.clear();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isTeacherPortal ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                border: !_isTeacherPortal ? Border.all(color: const Color(0xFFE2E8F0), width: 1) : null,
                                boxShadow: !_isTeacherPortal
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x03000000),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 16,
                                    color: !_isTeacherPortal ? const Color(0xFF10213E) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Student',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: !_isTeacherPortal ? FontWeight.bold : FontWeight.w500,
                                      color: !_isTeacherPortal ? const Color(0xFF10213E) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isTeacherPortal = true;
                                _usernameController.clear();
                                _passwordController.clear();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isTeacherPortal ? const Color(0xFF10213E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: _isTeacherPortal
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x03000000),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 16,
                                    color: _isTeacherPortal ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Teacher Portal',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: _isTeacherPortal ? FontWeight.bold : FontWeight.w500,
                                      color: _isTeacherPortal ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Official App Logo Emblem
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isTeacherPortal ? const Color(0xFFE8F0FE) : const Color(0xFFE5EEF8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x03000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Center(
                            child: Icon(
                              _isTeacherPortal ? Icons.school_outlined : Icons.account_balance_outlined,
                              size: 34,
                              color: const Color(0xFF10213E),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 18),

                  // Title "Smart Attendance"
                  Center(
                    child: Text(
                      'Smart Attendance',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 6),

                  // Subtitle matching Mockups
                  Center(
                    child: Text(
                      _isTeacherPortal ? 'Teacher Portal — Academic Admin' : 'Sign in with your Academic Account',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 28),

                  // White Form Card with Tiny Clean Minimal Shadow
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x03000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Label 1
                        Text(
                          _isTeacherPortal ? 'Teacher Email or Staff ID' : 'Email or Student ID',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Username / Email input
                        TextFormField(
                          controller: _usernameController,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF10213E),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            hintText: _isTeacherPortal ? 'emily.okonkwo@school.edu' : 'sarah.johnson@university.edu',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
                            prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF8C9BAE), size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your username or ID' : null,
                        ),

                        const SizedBox(height: 18),

                        // Label 2: Password
                        Text(
                          'Password',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF10213E),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            hintText: '••••••••••••',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
                            prefixIcon: Icon(
                              _isTeacherPortal ? Icons.key_outlined : Icons.lock_outline_rounded,
                              color: const Color(0xFF8C9BAE),
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF8C9BAE),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your password' : null,
                        ),

                        // In Teacher Portal: "Forgot Password?" right aligned above submit button (matching teacher-login.png)
                        if (_isTeacherPortal) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please contact your department administrator to reset credentials.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Action Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10213E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isTeacherPortal ? 'Login as Teacher' : 'Login',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        // In Student Mode: Centered "Forgot Password?" below login button (matching Mockup 02)
                        if (!_isTeacherPortal) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please contact student affairs or IT service desk to reset credentials.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // In Teacher Portal: "Verify Staff Biometrics"
                        if (_isTeacherPortal) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Staff biometric sensor ready. Tap a quick test account or enter credentials.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 20),
                              label: Text(
                                'Verify Staff Biometrics',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  // In Student Mode: OR Divider and "Sign in with School SSO"
                  if (!_isTeacherPortal) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x03000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('School SSO authentication initiated. Select your institution.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_outlined,
                              size: 19,
                              color: Color(0xFF10213E),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Sign in with School SSO',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 280.ms),
                  ],

                  const SizedBox(height: 20),

                  // Quick Demo Autofill section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x03000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Text(
                              _isTeacherPortal ? 'Quick Teacher Accounts' : 'Quick Student Accounts',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _isTeacherPortal
                              ? [
                                  _buildDemoChip('👨‍🏫 Dr. Sokha (Teacher)', 'teacher_sokha', 'TeacherPassword123!'),
                                  _buildDemoChip('👩‍🏫 Dr. Vanny (Teacher)', 'teacher_vanny', 'TeacherPassword123!'),
                                ]
                              : [
                                  _buildDemoChip('🎓 Dara (Student)', 'student_dara', 'StudentPassword123!'),
                                  _buildDemoChip('🎓 Bopha (Student)', 'student_bopha', 'StudentPassword123!'),
                                ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),

                  // Cloud connection indicator
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.present,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connected to student-attendance.vanny.monster',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoChip(String label, String username, String password) {
    return ActionChip(
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF10213E),
        ),
      ),
      onPressed: () => _fillCredentials(username, password),
    );
  }
}
