// lib/views/admin/add_tenant_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';

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
  // Step tracking
  int _currentStep = 0; // 0: Identitas, 1: Data Kos, 2: Akun Login
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  final _db = DatabaseHelper();
  final _picker = ImagePicker();

  // Step 1: Data Identitas
  final _namaCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _teleponCtrl = TextEditingController();

  // Step 2: Data Kos
  final _nomorKamarCtrl = TextEditingController();
  final _hargaSewaCtrl = TextEditingController();
  final _tanggalMasukCtrl = TextEditingController();

  // Step 3: Akun Login
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _isScanning = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _ocrError;

  // Available rooms
  List<String> _availableRooms = [];
  bool _isLoadingRooms = false;
  String? _selectedKamar;

  Future<void> _pickTanggalMasuk() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _tanggalMasukCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _loadAvailableRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      final rooms = await _db.getAvailableRooms();
      setState(() {
        _availableRooms = rooms;
        if (rooms.isNotEmpty && _selectedKamar == null) {
          _selectedKamar = rooms.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal memuat data kamar'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingRooms = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableRooms();
  }

  void _goToNextStep() {
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      if (_currentStep == 1 && _selectedKamar == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pilih nomor kamar terlebih dahulu'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Simpan selected kamar ke controller untuk save nanti
      _nomorKamarCtrl.text = _selectedKamar ?? '';
      setState(() => _currentStep += 1);
    }
  }

  void _goToPreviousStep() {
    setState(() => _currentStep -= 1);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _alamatCtrl.dispose();
    _teleponCtrl.dispose();
    _nomorKamarCtrl.dispose();
    _hargaSewaCtrl.dispose();
    _tanggalMasukCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
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
    if (!(_formKeys[2].currentState?.validate() ?? false)) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final tanggalMasuk = _tanggalMasukCtrl.text.trim();

      final user = UserModel(
        username: _usernameCtrl.text.trim(),
        password: DatabaseHelper.hashPassword(_passwordCtrl.text),
        role: 'tenant',
        isActive: true,
        nik: _nikCtrl.text.trim(),
        namaLengkap: _namaCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        nomorKamar: _nomorKamarCtrl.text.trim(),
        hargaSewa: int.tryParse(_hargaSewaCtrl.text.trim()),
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
      body: Column(
        children: [
          // ─── Step Indicator ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Identitas'),
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: _currentStep >= 1
                        ? const Color(0xFF1BC0BA)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                _buildStepIndicator(1, 'Kos'),
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: _currentStep >= 2
                        ? const Color(0xFF1BC0BA)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                _buildStepIndicator(2, 'Login'),
              ],
            ),
          ),

          // ─── Form Content ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(),
            ),
          ),

          // ─── Navigation Buttons ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goToPreviousStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                            color: Color(0xFF8095E4), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : (_currentStep < 2 ? _goToNextStep : _saveTenant),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            _currentStep < 2
                                ? Icons.arrow_forward_rounded
                                : Icons.person_add_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Menyimpan...'
                          : (_currentStep < 2 ? 'Lanjut' : 'Buat Akun'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8095E4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? const Color(0xFF1BC0BA)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF1BC0BA) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    return Form(
      key: _formKeys[_currentStep],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStep == 0) _buildStep1Content(),
          if (_currentStep == 1) _buildStep2Content(),
          if (_currentStep == 2) _buildStep3Content(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Scan KTP Penyewa', icon: Icons.document_scanner_rounded),
        const SizedBox(height: 14),
        _KTPScanCard(
          isScanning: _isScanning,
          ocrError: _ocrError,
          onScan: _scanKTP,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Data Identitas', icon: Icons.badge_rounded),
        const SizedBox(height: 12),
        _FormField(
          controller: _namaCtrl,
          label: 'Nama Lengkap *',
          hint: 'Sesuai KTP',
          icon: Icons.person_outline_rounded,
          maxLength: AppConstants.MAX_NAME_LENGTH,
          inputFormatters: [
            LengthLimitingTextInputFormatter(AppConstants.MAX_NAME_LENGTH),
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
          validator: (v) => null,
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
          validator: (v) => null,
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Data Kos', icon: Icons.home_work_rounded),
        const SizedBox(height: 12),
        // ── Dropdown Nomor Kamar ──
        _isLoadingRooms
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _availableRooms.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Semua kamar sudah terisi. Tidak ada kamar tersedia.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedKamar,
                    onChanged: (value) =>
                        setState(() => _selectedKamar = value),
                    items: _availableRooms
                        .map((kamar) => DropdownMenuItem(
                              value: kamar,
                              child: Text(kamar),
                            ))
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Nomor Kamar *',
                      hintText: 'Pilih kamar yang tersedia',
                      prefixIcon: const Icon(Icons.bedroom_parent_rounded,
                          size: 20, color: Color(0xFF8095E4)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF8095E4), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nomor kamar wajib dipilih';
                      }
                      return null;
                    },
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
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickTanggalMasuk,
          child: AbsorbPointer(
            child: _FormField(
              controller: _tanggalMasukCtrl,
              label: 'Tanggal Masuk *',
              hint: 'Pilih tanggal masuk',
              icon: Icons.calendar_month_rounded,
              maxLength: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tanggal masuk wajib diisi';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Akun Login Penyewa', icon: Icons.lock_outline_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1BC0BA).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1BC0BA).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: const Color(0xFF1BC0BA), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Penyewa dapat mengganti password setelah login pertama kali.',
                  style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1BC0BA).withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _FormField(
          controller: _usernameCtrl,
          label: 'Username *',
          hint: 'Satu kata, tanpa spasi',
          icon: Icons.alternate_email_rounded,
          maxLength: AppConstants.MAX_USERNAME_LENGTH,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            LengthLimitingTextInputFormatter(AppConstants.MAX_USERNAME_LENGTH),
          ],
          validator: AppValidators.validateUsername,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          maxLength: AppConstants.MAX_PASSWORD_LENGTH,
          inputFormatters: [
            LengthLimitingTextInputFormatter(AppConstants.MAX_PASSWORD_LENGTH),
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
                borderSide:
                    const BorderSide(color: Color(0xFF8095E4), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE53935))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordConfirmCtrl,
          obscureText: _obscurePasswordConfirm,
          maxLength: AppConstants.MAX_PASSWORD_LENGTH,
          inputFormatters: [
            LengthLimitingTextInputFormatter(AppConstants.MAX_PASSWORD_LENGTH),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Konfirmasi password wajib diisi';
            }
            if (value != _passwordCtrl.text) {
              return 'Password tidak cocok';
            }
            return null;
          },
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            labelText: 'Konfirmasi Password *',
            hintText: 'Ulangi password',
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 20, color: Color(0xFF8095E4)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePasswordConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
              onPressed: () => setState(
                  () => _obscurePasswordConfirm = !_obscurePasswordConfirm),
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
                borderSide:
                    const BorderSide(color: Color(0xFF8095E4), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE53935))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
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
