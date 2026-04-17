// lib/views/shared/saran_kesan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class SaranKesanScreen extends StatefulWidget {
  const SaranKesanScreen({super.key});

  @override
  State<SaranKesanScreen> createState() => _SaranKesanScreenState();
}

class _SaranKesanScreenState extends State<SaranKesanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saranCtrl = TextEditingController();
  final _kesanCtrl = TextEditingController();
  bool _isSaved = false;

  static const _keyKesan = 'saran_kesan_kesan';
  static const _keySaran = 'saran_kesan_saran';
  static const _keySaved = 'saran_kesan_is_saved';

  // Data hardcoded mata kuliah TPM
  static const _mataKuliah = 'Teknologi Pemrograman Mobile (TPM)';
  static const _dosen = 'Nama Dosen Pengampu'; // Ganti sesuai dosen asli
  static const _semester = 'Semester Gasal 2025/2026';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_keySaved) ?? false;
    if (saved) {
      _kesanCtrl.text = prefs.getString(_keyKesan) ?? '';
      _saranCtrl.text = prefs.getString(_keySaran) ?? '';
      setState(() => _isSaved = true);
    }
  }

  @override
  void dispose() {
    _saranCtrl.dispose();
    _kesanCtrl.dispose();
    super.dispose();
  }

  void _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKesan, _kesanCtrl.text);
    await prefs.setString(_keySaran, _saranCtrl.text);
    await prefs.setBool(_keySaved, true);

    setState(() => _isSaved = true);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saran & Kesan berhasil disimpan. Terima kasih!'),
          backgroundColor: const Color(0xFF1BC0BA),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Saran & Kesan TPM',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF8095E4)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Mata Kuliah
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF8095E4).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF8095E4).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_rounded,
                            color: Color(0xFF8095E4), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            _mataKuliah,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Dosen', value: _dosen),
                    const SizedBox(height: 4),
                    _InfoRow(label: 'Semester', value: _semester),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Kesan
              const _FieldLabel(text: 'Kesan terhadap mata kuliah TPM'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _kesanCtrl,
                maxLines: 5,
                maxLength: AppConstants.MAX_SARAN_LENGTH,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                      AppConstants.MAX_SARAN_LENGTH),
                ],
                validator: AppValidators.validateSaranKesan,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: _inputDecoration(
                  hint: 'Tulis kesan kamu selama mengikuti mata kuliah ini...',
                ),
              ),
              const SizedBox(height: 16),

              // Saran
              const _FieldLabel(text: 'Saran untuk mata kuliah TPM'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _saranCtrl,
                maxLines: 5,
                maxLength: AppConstants.MAX_SARAN_LENGTH,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                      AppConstants.MAX_SARAN_LENGTH),
                ],
                validator: AppValidators.validateSaranKesan,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: _inputDecoration(
                  hint:
                      'Tulis saran kamu untuk pengembangan mata kuliah ini...',
                ),
              ),
              const SizedBox(height: 28),

              // Tombol simpan
              if (!_isSaved)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: const Text('Simpan Saran & Kesan',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8095E4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1BC0BA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF1BC0BA).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF1BC0BA)),
                      SizedBox(width: 8),
                      Text('Sudah disimpan. Terima kasih!',
                          style: TextStyle(
                            color: Color(0xFF0F6E56),
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8095E4), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}

// ─── Helper ────────────────────────────────────────────────────────────────────

// Expose maxLength untuk digunakan di validators
extension AppValidatorsExt on AppValidators {
  static int get maxSaranLength => 1000;
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text('$label:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E))),
        ),
      ],
    );
  }
}
