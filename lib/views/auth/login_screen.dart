// lib/views/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthController.to;

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Hapus focus keyboard
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final result = await _auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.user != null) {
      _navigateAfterLogin(result.user!.isAdmin);
    } else {
      _showError(result.message ?? 'Login gagal. Coba lagi.');
    }
  }

  void _navigateAfterLogin(bool isAdmin) {
    if (isAdmin) {
      Get.offAllNamed('/admin/dashboard');
    } else {
      Get.offAllNamed('/tenant/dashboard');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              height: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildForm(),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  _buildBiometricButton(),
                  const SizedBox(height: 40),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF8095E4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kostify',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Smart Boarding Management System',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Username
          _KostifyTextField(
            controller: _usernameCtrl,
            label: 'Username',
            hint: 'Masukkan username',
            icon: Icons.person_outline_rounded,
            maxLength: AppConstants.MAX_USERNAME_LENGTH,
            // Larang spasi pada username
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              LengthLimitingTextInputFormatter(AppConstants.MAX_USERNAME_LENGTH),
              // Larang karakter SQL injection
              FilteringTextInputFormatter.deny(RegExp(r'''[''<>]''')),
            ],
            textInputAction: TextInputAction.next,
            validator: AppValidators.validateUsername,
          ),
          const SizedBox(height: 16),
          // Password
          _KostifyTextField(
            controller: _passwordCtrl,
            label: 'Password',
            hint: 'Masukkan password',
            icon: Icons.lock_outline_rounded,
            maxLength: AppConstants.MAX_PASSWORD_LENGTH,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            inputFormatters: [
              LengthLimitingTextInputFormatter(AppConstants.MAX_PASSWORD_LENGTH),
            ],
            validator: AppValidators.validatePassword,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF6B7280),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Obx(() => ElevatedButton(
        onPressed: (_isSubmitting || _auth.isLoading.value) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8095E4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF8095E4).withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: (_isSubmitting || _auth.isLoading.value)
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Masuk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      )),
    );
  }

  Widget _buildBiometricButton() {
    return Obx(() {
      if (!_auth.isBiometricAvailable.value) return const SizedBox.shrink();
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _biometricOnlyLogin,
          icon: const Icon(Icons.fingerprint_rounded, size: 22),
          label: const Text('Login dengan Biometrik'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8095E4),
            side: const BorderSide(color: Color(0xFF8095E4), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    });
  }

  /// Login menggunakan biometric saja (jika sudah ada session tersimpan)
  Future<void> _biometricOnlyLogin() async {
    if (_auth.isLoggedIn) {
      _navigateAfterLogin(_auth.isAdmin);
      return;
    }
    // Jika tidak ada session, minta isi form dulu
    _showError('Masukkan username & password terlebih dahulu untuk login pertama kali.');
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        '${AppConstants.APP_NAME} v${AppConstants.APP_VERSION}',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

// ─── Reusable TextField ────────────────────────────────────────────────────────

class _KostifyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;
  final bool obscureText;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _KostifyTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
    this.obscureText = false,
    this.validator,
    this.inputFormatters,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '', // Sembunyikan counter karakter bawaan
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8095E4)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8095E4), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
