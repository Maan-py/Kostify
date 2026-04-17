// lib/views/admin/add_tenant_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../models/user_model.dart';
import '../../services/database_helper.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../auth/login_screen.dart'; // reuse _KostifyTextField

class AddTenantScreen extends StatefulWidget {
  const AddTenantScreen({super.key});

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _picker = ImagePicker();

  // Controllers
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _nomorKamarCtrl = TextEditingController();
  final _hargaSewaCtrl = TextEditingController();
  final _teleponCtrl = TextEditingController();

  bool _isScanning = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  String? _ocrError;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _alamatCtrl.dispose();
    _nomorKamarCtrl.dispose();
    _hargaSewaCtrl.dispose();
    _teleponCtrl.dispose();
    super.dispose();
  }

  // ─── OCR KTP ──────────────────────────────────────────────────────────────

  Future<void> _scanKTP() async {
    setState(() {
      _isScanning = true;
      _ocrError = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (picked == null) {
        setState(() => _isScanning = false);
        return;
      }

      // Compress dulu sebelum proses
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: AppConstants.IMAGE_QUALITY,
        minWidth: 800,
        minHeight: 500,
      );

      if (compressed == null) throw Exception('Gagal memproses gambar');

      // Tulis ke file temp untuk ML Kit
      final tempPath = '${picked.path}_compressed.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(compressed);

      // OCR
      final inputImage = InputImage.fromFilePath(tempPath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognized = await recognizer.processImage(inputImage);
        _parseKTPText(recognized.text);
      } finally {
        await recognizer.close();
        // Hapus file temp setelah diproses
        try {
          await tempFile.delete();
        } catch (_) {}
        try {
          await File(picked.path).delete();
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _ocrError =
            'Gagal membaca KTP. Pastikan foto jelas dan cukup cahaya. Isi manual jika perlu.';
      });
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _parseKTPText(String rawText) {
    // Parsing sederhana berdasarkan kata kunci KTP Indonesia
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final fullText = rawText.toUpperCase();

    String nik = '';
    String nama = '';
    String alamat = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineUpper = line.toUpperCase();

      // NIK: 16 digit, biasanya baris setelah label "NIK"
      if (nik.isEmpty) {
        if (lineUpper.contains('NIK')) {
          // Cari angka 16 digit di baris ini atau berikutnya
          final nikMatch = RegExp(r'\b\d{16}\b').firstMatch(line);
          if (nikMatch != null) {
            nik = nikMatch.group(0)!;
          } else if (i + 1 < lines.length) {
            final nextNik = RegExp(r'\b\d{16}\b').firstMatch(lines[i + 1]);
            if (nextNik != null) nik = nextNik.group(0)!;
          }
        } else {
          final standaloneNik = RegExp(r'\b\d{16}\b').firstMatch(line);
          if (standaloneNik != null) nik = standaloneNik.group(0)!;
        }
      }

      // Nama: baris setelah label "NAMA"
      if (nama.isEmpty && lineUpper.contains('NAMA')) {
        final afterNama = line
            .replaceAll(RegExp(r'NAMA\s*[:\-]?\s*', caseSensitive: false), '')
            .trim();
        if (afterNama.length >= 3) {
          nama = _toTitleCase(afterNama);
        } else if (i + 1 < lines.length) {
          nama = _toTitleCase(lines[i + 1]);
        }
      }

      // Alamat: baris setelah label "ALAMAT"
      if (alamat.isEmpty && lineUpper.contains('ALAMAT')) {
        final afterAlamat = line
            .replaceAll(RegExp(r'ALAMAT\s*[:\-]?\s*', caseSensitive: false), '')
            .trim();
        if (afterAlamat.length >= 3) {
          alamat = afterAlamat;
        } else if (i + 1 < lines.length) {
          alamat = lines[i + 1];
        }
      }
    }

    // Isi field yang berhasil diekstrak
    bool anyFilled = false;
    setState(() {
      if (nik.isNotEmpty && _nikCtrl.text.isEmpty) {
        _nikCtrl.text = nik;
        anyFilled = true;
      }
      if (nama.isNotEmpty && _namaCtrl.text.isEmpty) {
        _namaCtrl.text = nama;
        anyFilled = true;
        // Auto-generate username dari nama (ambil kata pertama, lowercase)
        if (_usernameCtrl.text.isEmpty) {
          final firstWord = nama
              .split(' ')
              .first
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
          _usernameCtrl.text = firstWord;
        }
      }
      if (alamat.isNotEmpty && _alamatCtrl.text.isEmpty) {
        _alamatCtrl.text = alamat;
        anyFilled = true;
      }
      if (!anyFilled) {
        _ocrError =
            'OCR tidak dapat membaca data KTP. Silakan isi form secara manual.';
      }
    });

    if (anyFilled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Data KTP berhasil diekstrak! Periksa dan lengkapi form.'),
          backgroundColor: const Color(0xFF1BC0BA),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _toTitleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  // ─── Save Tenant ──────────────────────────────────────────────────────────

  Future<void> _saveTenant() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final hargaStr =
          _hargaSewaCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
      final harga = int.tryParse(hargaStr) ?? 0;

      final tanggalMasuk = DateTime.now().toIso8601String().split('T').first;

      final user = UserModel(
        username: _usernameCtrl.text.trim(),
        password: DatabaseHelper.hashPassword(_passwordCtrl.text),
        role: 'tenant',
        isActive: true,
        nik: _nikCtrl.text.trim(),
        namaLengkap: _namaCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        nomorKamar: _nomorKamarCtrl.text.trim(),
        hargaSewa: harga,
        telepon: _teleponCtrl.text.trim().isNotEmpty
            ? _teleponCtrl.text.trim()
            : null,
        tanggalMasuk: tanggalMasuk,
        createdAt: DateTime.now(),
      );

      await _db.createTenant(user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun ${user.namaLengkap} berhasil dibuat!'),
            backgroundColor: const Color(0xFF1BC0BA),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Get.back(result: true);
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Tambah Penghuni',
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
              // ── Scan KTP Section ──
              _SectionHeader(
                  title: 'Scan KTP (Opsional)',
                  icon: Icons.document_scanner_rounded),
              const SizedBox(height: 10),
              _KTPScanCard(
                isScanning: _isScanning,
                ocrError: _ocrError,
                onScan: _scanKTP,
              ),
              const SizedBox(height: 24),

              // ── Data Identitas ──
              _SectionHeader(
                  title: 'Data Identitas', icon: Icons.badge_rounded),
              const SizedBox(height: 12),
              _FormField(
                controller: _namaCtrl,
                label: 'Nama Lengkap *',
                hint: 'Sesuai KTP',
                icon: Icons.person_outline_rounded,
                maxLength: AppConstants.MAX_NAME_LENGTH,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                      AppConstants.MAX_NAME_LENGTH),
                  FilteringTextInputFormatter.deny(RegExp(r'''['";\\<>]''')),
                ],
                validator: AppValidators.validateNamaLengkap,
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _nikCtrl,
                label: 'NIK *',
                hint: '16 digit angka',
                icon: Icons.credit_card_rounded,
                maxLength: AppConstants.NIK_LENGTH,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AppConstants.NIK_LENGTH),
                ],
                validator: AppValidators.validateNIK,
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _alamatCtrl,
                label: 'Alamat KTP',
                hint: 'Alamat sesuai KTP',
                icon: Icons.home_outlined,
                maxLength: 200,
                maxLines: 3,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(200),
                  FilteringTextInputFormatter.deny(RegExp(r'''['";\\<>]''')),
                ],
                validator: (v) => null, // opsional
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _teleponCtrl,
                label: 'Nomor Telepon',
                hint: '08xxxxxxxxxx',
                icon: Icons.phone_outlined,
                maxLength: 15,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                validator: (v) => null, // opsional
              ),
              const SizedBox(height: 24),

              // ── Data Kos ──
              _SectionHeader(title: 'Data Kos', icon: Icons.home_work_rounded),
              const SizedBox(height: 12),
              _FormField(
                controller: _nomorKamarCtrl,
                label: 'Nomor Kamar *',
                hint: 'cth: A1, 101, B-2',
                icon: Icons.bedroom_parent_rounded,
                maxLength: 10,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.deny(RegExp(r'''['";\\<>]''')),
                ],
                validator: AppValidators.validateNomorKamar,
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _hargaSewaCtrl,
                label: 'Harga Sewa/Bulan (IDR) *',
                hint: 'cth: 1500000',
                icon: Icons.payments_rounded,
                maxLength: 12,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: AppValidators.validateHargaSewa,
              ),
              const SizedBox(height: 24),

              // ── Akun Login ──
              _SectionHeader(
                  title: 'Akun Login', icon: Icons.lock_outline_rounded),
              const SizedBox(height: 12),
              _FormField(
                controller: _usernameCtrl,
                label: 'Username *',
                hint: 'Satu kata, tanpa spasi',
                icon: Icons.alternate_email_rounded,
                maxLength: AppConstants.MAX_USERNAME_LENGTH,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(
                      AppConstants.MAX_USERNAME_LENGTH),
                ],
                validator: AppValidators.validateUsername,
              ),
              const SizedBox(height: 14),
              // Password field dengan toggle visibility
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                maxLength: AppConstants.MAX_PASSWORD_LENGTH,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                      AppConstants.MAX_PASSWORD_LENGTH),
                ],
                validator: AppValidators.validatePassword,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  labelText: 'Password Awal *',
                  hintText: 'Min. 6 karakter',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 20, color: Color(0xFF8095E4)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF6B7280),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF8095E4), width: 1.5)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE53935))),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '💡 Penyewa dapat mengganti password setelah login pertama kali.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTenant,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_rounded, size: 20),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Buat Akun Penyewa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8095E4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── KTP Scan Card ────────────────────────────────────────────────────────────

class _KTPScanCard extends StatelessWidget {
  final bool isScanning;
  final String? ocrError;
  final VoidCallback onScan;

  const _KTPScanCard(
      {required this.isScanning, this.ocrError, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ocrError != null
              ? Colors.orange.shade300
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          if (ocrError != null) ...[
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ocrError!,
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8095E4).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: Color(0xFF8095E4), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scan KTP Penyewa',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(
                      'Foto KTP akan diproses OCR dan dihapus otomatis setelah ekstraksi.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: isScanning ? null : onScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8095E4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Scan', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8095E4)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            )),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8095E4)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF8095E4), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935))),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: maxLines > 1 ? 12 : 14),
      ),
    );
  }
}
