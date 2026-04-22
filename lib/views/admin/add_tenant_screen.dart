// lib/views/admin/add_tenant_screen.dart

import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/database_helper.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'ktp_camera_capture_screen.dart';
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
  Uint8List? _debugImageBytes;
  Size? _debugImageSize;
  List<_KtpDebugBox> _debugBoxes = [];

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
    final source = await _showScanSourcePicker();
    if (source == null) return;

    String? capturedPath;
    if (source == ImageSource.camera) {
      capturedPath = await Get.to<String>(() => const KtpCameraCaptureScreen());
    } else {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2500,
      );
      capturedPath = picked?.path;
    }

    if (capturedPath == null || capturedPath.isEmpty) return;

    setState(() {
      _isScanning = true;
      _ocrError = null;
      _debugBoxes = [];
    });

    try {
      // Compress + auto-fix EXIF rotation (penting untuk foto landscape/portrait)
      // keepExif: false agar orientasi di-bake ke pixel, bukan cuma metadata
      // minWidth/minHeight pakai 0 agar tidak distorsi — biarkan proporsional
      final compressed = await FlutterImageCompress.compressWithFile(
        capturedPath,
        quality: AppConstants.IMAGE_QUALITY,
        minWidth: 1024,
        minHeight: 0, // 0 = proporsional, tidak paksa tinggi tertentu
        rotate: 0, // 0 = ikuti EXIF, library akan auto-correct orientasi
        keepExif: false, // strip EXIF agar ML Kit tidak salah baca orientasi
      );

      if (compressed == null) throw Exception('Gagal memproses gambar');

      final guidedBytes = await _cropToGuideBox(Uint8List.fromList(compressed));
      await _setDebugImage(guidedBytes);

      // Tulis ke file temp untuk ML Kit
  final tempPath = '${capturedPath}_compressed.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(guidedBytes);

      // OCR
      final inputImage = InputImage.fromFilePath(tempPath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognized = await recognizer.processImage(inputImage);
        if (recognized.text.trim().isEmpty) {
          setState(() {
            _ocrError =
                'Gambar tidak terbaca. Pastikan KTP tidak buram, ada cahaya cukup, dan seluruh KTP masuk frame.';
          });
        } else {
          _parseKTPResult(recognized);
        }
      } finally {
        await recognizer.close();
        // Hapus file temp setelah diproses
        try {
          await tempFile.delete();
        } catch (_) {}
        if (source == ImageSource.camera) {
          try {
            await File(capturedPath).delete();
          } catch (_) {}
        }
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

  Future<ImageSource?> _showScanSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Kamera (dengan frame KTP)'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List> _cropToGuideBox(Uint8List bytes) async {
    try {
      final source = img.decodeImage(bytes);
      if (source == null) return bytes;

      const targetAspect = 1.58; // Rasio KTP approx
      int cropWidth = (source.width * 0.88).round();
      int cropHeight = (cropWidth / targetAspect).round();

      final maxHeight = (source.height * 0.72).round();
      if (cropHeight > maxHeight) {
        cropHeight = maxHeight;
        cropWidth = (cropHeight * targetAspect).round();
      }

      cropWidth = math.min(cropWidth, source.width);
      cropHeight = math.min(cropHeight, source.height);

      final x = ((source.width - cropWidth) / 2).round().clamp(0, source.width - cropWidth);
      final y = ((source.height - cropHeight) / 2).round().clamp(0, source.height - cropHeight);

      final cropped = img.copyCrop(
        source,
        x: x,
        y: y,
        width: cropWidth,
        height: cropHeight,
      );

      return Uint8List.fromList(
        img.encodeJpg(cropped, quality: AppConstants.IMAGE_QUALITY),
      );
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _setDebugImage(Uint8List bytes) async {
    final size = await _decodeImageSize(bytes);
    if (!mounted) return;
    setState(() {
      _debugImageBytes = bytes;
      _debugImageSize = size;
    });
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final completer = Completer<Size?>();
      ui.decodeImageFromList(bytes, (image) {
        completer.complete(
          Size(image.width.toDouble(), image.height.toDouble()),
        );
      });
      return completer.future;
    } catch (_) {
      return null;
    }
  }

  // Metode ala artikel: cari koordinat label dulu, lalu ambil value yang sejajar.
  void _parseKTPResult(RecognizedText recognized) {
    final ocrLines = <_KtpOcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        ocrLines.add(_KtpOcrLine(text: text, rect: line.boundingBox));
      }
    }

    if (ocrLines.isEmpty) {
      _parseKTPText(recognized.text);
      return;
    }

    ocrLines.sort((a, b) => a.rect.top.compareTo(b.rect.top));

    Rect? nikLabelRect;
    Rect? namaLabelRect;
    Rect? alamatLabelRect;
    Rect? rtRwLabelRect;
    Rect? kelDesaLabelRect;
    Rect? kecamatanLabelRect;
    final maxRight = ocrLines
      .map((line) => line.rect.right)
      .fold<double>(0, (prev, cur) => cur > prev ? cur : prev);

    for (final line in ocrLines) {
      final normalized = _normalizeFieldText(line.text);
      if (nikLabelRect == null && _isNikLabel(normalized)) {
        nikLabelRect = line.rect;
      }
      if (namaLabelRect == null && _isNamaLabel(normalized)) {
        namaLabelRect = line.rect;
      }
      if (alamatLabelRect == null && _isAlamatLabel(normalized)) {
        alamatLabelRect = line.rect;
      }
      if (rtRwLabelRect == null && _isRtRwLabel(normalized)) {
        rtRwLabelRect = line.rect;
      }
      if (kelDesaLabelRect == null && _isKelDesaLabel(normalized)) {
        kelDesaLabelRect = line.rect;
      }
      if (kecamatanLabelRect == null && _isKecamatanLabel(normalized)) {
        kecamatanLabelRect = line.rect;
      }
    }

    var nik = _extractNikByLayout(ocrLines, nikLabelRect);
    if (nik.isEmpty) {
      nik = _extractNikFromRawText(recognized.text);
    }
    final nama = _extractSingleValueByAlignment(ocrLines, namaLabelRect,
        isName: true);
    final alamat = _extractAlamatComposite(
      lines: ocrLines,
      alamatLabelRect: alamatLabelRect,
      rtRwLabelRect: rtRwLabelRect,
      kelDesaLabelRect: kelDesaLabelRect,
      kecamatanLabelRect: kecamatanLabelRect,
      rawText: recognized.text,
    );

    final debugBoxes = <_KtpDebugBox>[];
    for (final line in ocrLines) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: line.rect,
          color: Colors.white70,
          label: '',
          strokeWidth: 0.6,
        ),
      );
    }

    if (nikLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: nikLabelRect,
          color: const Color(0xFF42A5F5),
          label: 'Label NIK',
        ),
      );
    }
    if (namaLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: namaLabelRect,
          color: const Color(0xFF7E57C2),
          label: 'Label Nama',
        ),
      );
    }
    if (alamatLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: alamatLabelRect,
          color: const Color(0xFFFFA726),
          label: 'Label Alamat',
        ),
      );
    }
    if (rtRwLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: rtRwLabelRect,
          color: const Color(0xFFEF5350),
          label: 'Label RT/RW',
        ),
      );
    }
    if (kelDesaLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: kelDesaLabelRect,
          color: const Color(0xFFFF7043),
          label: 'Label Kel/Desa',
        ),
      );
    }
    if (kecamatanLabelRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: kecamatanLabelRect,
          color: const Color(0xFFFF8A65),
          label: 'Label Kecamatan',
        ),
      );
    }

    final nikRect = _findNikValueRectNearLabel(ocrLines, nikLabelRect, nik) ??
      _findNikValueRect(ocrLines, nik);
    if (nikRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: nikRect,
          color: const Color(0xFF26C6DA),
          label: 'Value NIK',
        ),
      );
    }

    final namaRect = _findValueRectByText(ocrLines, nama);
    if (namaRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: namaRect,
          color: const Color(0xFFAB47BC),
          label: 'Value Nama',
        ),
      );
    }

    final alamatRect = _buildAlamatAreaRect(
      alamatLabelRect,
      kecamatanLabelRect,
      maxRight,
    );
    if (alamatRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: alamatRect,
          color: const Color(0x33FFA726),
          label: 'Area Alamat',
          filled: true,
          strokeWidth: 1.2,
        ),
      );
    }

    final alamatValueRect = _findValueRectByText(ocrLines, alamat);
    if (alamatValueRect != null) {
      debugBoxes.add(
        _KtpDebugBox(
          rect: alamatValueRect,
          color: const Color(0xFFFFB300),
          label: 'Value Alamat',
        ),
      );
    }

    if (mounted) {
      setState(() {
        _debugBoxes = debugBoxes;
      });
    }

    if (nik.isEmpty && nama.isEmpty && alamat.isEmpty) {
      _parseKTPText(recognized.text);
      return;
    }

    _applyParsedKTPData(nik: nik, nama: nama, alamat: alamat);
  }

  Rect? _findNikValueRect(List<_KtpOcrLine> lines, String nik) {
    if (nik.isEmpty) return null;
    for (final line in lines) {
      final cleaned = line.text
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il]'), '1')
          .replaceAll(RegExp(r'\D'), '');
      if (cleaned.contains(nik)) return line.rect;
    }
    return null;
  }

  Rect? _findNikValueRectNearLabel(
    List<_KtpOcrLine> lines,
    Rect? nikLabelRect,
    String nik,
  ) {
    if (nik.isEmpty) return null;

    final targetDigits = nik.replaceAll(RegExp(r'\D'), '');
    if (targetDigits.length != AppConstants.NIK_LENGTH) return null;

    bool hasNikDigits(String text) {
      final digits = text
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il]'), '1')
          .replaceAll(RegExp(r'\D'), '');
      return digits == targetDigits || digits.contains(targetDigits);
    }

    if (nikLabelRect != null) {
      final nearbyLines = lines.where((line) {
        final sameColumn = line.rect.left >= nikLabelRect.left - 16;
        final belowLabel = line.rect.top >= nikLabelRect.bottom - 4;
        final closeBy = line.rect.top - nikLabelRect.bottom <= 72;
        return sameColumn && belowLabel && closeBy;
      }).toList()
        ..sort((a, b) => a.rect.top.compareTo(b.rect.top));

      for (final line in nearbyLines) {
        if (hasNikDigits(line.text)) return line.rect;
      }
    }

    for (final line in lines) {
      if (hasNikDigits(line.text)) return line.rect;
    }
    return null;
  }

  Rect? _findValueRectByText(List<_KtpOcrLine> lines, String value) {
    if (value.trim().isEmpty) return null;
    final normalizedTarget = value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    for (final line in lines) {
      final normalizedLine =
          line.text.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalizedLine.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedLine)) {
        return line.rect;
      }
    }
    return null;
  }

  Rect? _buildAlamatAreaRect(
    Rect? alamatLabelRect,
    Rect? kecamatanLabelRect,
    double maxRight,
  ) {
    if (alamatLabelRect == null) return null;
    final left =
        (alamatLabelRect.left - 12).clamp(0, double.infinity).toDouble();
    final top =
        (alamatLabelRect.bottom - 4).clamp(0, double.infinity).toDouble();
    final right = (maxRight + 8).clamp(left + 1, double.infinity).toDouble();
        final bottom = (kecamatanLabelRect?.bottom ??
          (alamatLabelRect.bottom + 180).clamp(top + 1, double.infinity))
        .toDouble();
    if (bottom <= top || right <= left) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  String _normalizeFieldText(String text) {
    return text
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('4', 'A')
        .replaceAll(RegExp(r'[^A-Z]'), '');
  }

  bool _isNikLabel(String text) => text.contains('NIK');
  bool _isNamaLabel(String text) => text.contains('NAMA') || text.contains('NAME');
  bool _isAlamatLabel(String text) => text.contains('ALAMAT') || text.contains('LAMAT');
    bool _isRtRwLabel(String text) =>
      text.contains('RTRW') ||
      (text.contains('RT') && text.contains('RW')) ||
      text.contains('RTR');
    bool _isKelDesaLabel(String text) =>
      text.contains('KELDESA') ||
      text.contains('KELURAHAN') ||
      text.contains('DESA') ||
      text.contains('KEL');
    bool _isKecamatanLabel(String text) => text.contains('KECAMATAN');

  bool _looksLikeFieldLabel(String text) {
    final normalized = _normalizeFieldText(text);
    return _isNikLabel(normalized) ||
        _isNamaLabel(normalized) ||
        _isAlamatLabel(normalized) ||
      _isRtRwLabel(normalized) ||
      _isKelDesaLabel(normalized) ||
      _isKecamatanLabel(normalized) ||
        normalized.contains('KECAMATAN') ||
        normalized.contains('KELURAHAN') ||
        normalized.contains('STATUS') ||
        normalized.contains('PEKERJAAN') ||
        normalized.contains('KEWARGANEGARAAN') ||
        normalized.contains('BERLAKU');
  }

  String _extractNikByLayout(List<_KtpOcrLine> lines, Rect? nikLabelRect) {
    String tryExtract(String text) {
      final normalized = text
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il]'), '1');
      final digits = normalized.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 16) return digits.substring(0, 16);
      return '';
    }

    if (nikLabelRect != null) {
      final sameRow = lines.where((line) {
        final yDelta = (line.rect.center.dy - nikLabelRect.center.dy).abs();
        return yDelta <= 30 && line.rect.left >= nikLabelRect.right - 8;
      }).toList()
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));

      for (final line in sameRow) {
        final nik = tryExtract(line.text);
        if (nik.isNotEmpty) return nik;
      }

      final belowRow = lines.where((line) {
        final isBelow = line.rect.top >= nikLabelRect.bottom - 4;
        final yClose = line.rect.top - nikLabelRect.bottom <= 44;
        final xAligned = line.rect.left >= nikLabelRect.left - 12;
        return isBelow && yClose && xAligned;
      }).toList()
        ..sort((a, b) => a.rect.top.compareTo(b.rect.top));

      for (final line in belowRow) {
        final nik = tryExtract(line.text);
        if (nik.isNotEmpty) return nik;
      }
    }

    for (final line in lines) {
      final nik = tryExtract(line.text);
      if (nik.isNotEmpty) return nik;
    }
    return '';
  }

  String _extractNikFromRawText(String rawText) {
    final upper = rawText.toUpperCase();
    final normalized = upper
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Il]'), '1');

    final aroundNik = RegExp(r'NIK[^\n\r]{0,40}(\d[\d\s\-:]{14,}\d)')
        .firstMatch(normalized);
    if (aroundNik != null) {
      final candidate = _normalizeNikValue(aroundNik.group(1) ?? '');
      if (candidate.isNotEmpty) return candidate;
    }

    final generic = RegExp(r'\d[\d\s\-:]{14,}\d').allMatches(normalized);
    for (final match in generic) {
      final candidate = _normalizeNikValue(match.group(0) ?? '');
      if (candidate.isNotEmpty) return candidate;
    }

    return '';
  }

  String _normalizeNikValue(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[OoDd]'), '0')
      .replaceAll(RegExp(r'[Il|]'), '1')
      .replaceAll(RegExp(r'[bB]'), '6')
      .replaceAll(RegExp(r'[sS]'), '5')
      .replaceAll(RegExp(r'\D'), ''); // Hapus semua yang bukan angka setelah konversi
  
  if (cleaned.length < 16) return '';
  return cleaned.substring(0, 16);
}

  bool _isValidOcrName(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return false;
    if (RegExp(r'\d').hasMatch(trimmed)) return false;
    return RegExp(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ '\-]*$").hasMatch(trimmed);
  }

  String _normalizeNameCandidate(String input) {
    final candidate = input
        .replaceAll(RegExp(r'^[\s:\-]+'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (!_isValidOcrName(candidate)) return '';
    return _toTitleCase(candidate.replaceAll(RegExp(r'\s+'), ' '));
  }

  String _extractSingleValueByAlignment(
    List<_KtpOcrLine> lines,
    Rect? labelRect, {
    bool isName = false,
  }) {
    if (labelRect == null) return '';

    String clean(String input) {
      final value = input
          .replaceAll(RegExp(r'^[\s:\-]+'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (value.isEmpty || _looksLikeFieldLabel(value)) return '';
      if (isName) {
        if (!_isValidOcrName(value)) return '';
        return _toTitleCase(value.replaceAll(RegExp(r'\s+'), ' '));
      }
      return value;
    }

    final sameRow = lines.where((line) {
      final yDelta = (line.rect.center.dy - labelRect.center.dy).abs();
      return yDelta <= 20 && line.rect.left >= labelRect.right - 8;
    }).toList()
      ..sort((a, b) => a.rect.left.compareTo(b.rect.left));

    for (final line in sameRow) {
      final value = clean(line.text);
      if (value.isNotEmpty) return value;
    }

    final belowRow = lines.where((line) {
      final isBelow = line.rect.top >= labelRect.bottom - 4;
      final yClose = line.rect.top - labelRect.bottom <= 44;
      final xAligned = line.rect.left >= labelRect.left - 12;
      return isBelow && yClose && xAligned;
    }).toList()
      ..sort((a, b) => a.rect.top.compareTo(b.rect.top));

    for (final line in belowRow) {
      final value = clean(line.text);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  String _extractAlamatComposite({
    required List<_KtpOcrLine> lines,
    required Rect? alamatLabelRect,
    required Rect? rtRwLabelRect,
    required Rect? kelDesaLabelRect,
    required Rect? kecamatanLabelRect,
    required String rawText,
  }) {
    String cleanAddressPart(String input) {
      return input
          .replaceAll(RegExp(r'^(ALAMAT|RT\s*\/\s*RW|RTRW|KEL\s*\/\s*DESA|KELURAHAN|DESA|KECAMATAN)\s*[:\-]?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    String pickPart(Rect? labelRect) {
      if (labelRect == null) return '';
      final value = _extractSingleValueByAlignment(lines, labelRect);
      return cleanAddressPart(value);
    }

    final alamatMain = pickPart(alamatLabelRect);
    final rtRw = pickPart(rtRwLabelRect);
    final kelDesa = pickPart(kelDesaLabelRect);
    final kecamatan = pickPart(kecamatanLabelRect);

    final rawMap = _extractAlamatComponentsFromRawText(rawText);

    final merged = <String>[
      if (alamatMain.isNotEmpty) alamatMain else if ((rawMap['alamat'] ?? '').isNotEmpty) rawMap['alamat']!,
      if (rtRw.isNotEmpty) rtRw else if ((rawMap['rtrw'] ?? '').isNotEmpty) rawMap['rtrw']!,
      if (kelDesa.isNotEmpty) kelDesa else if ((rawMap['keldesa'] ?? '').isNotEmpty) rawMap['keldesa']!,
      if (kecamatan.isNotEmpty) kecamatan else if ((rawMap['kecamatan'] ?? '').isNotEmpty) rawMap['kecamatan']!,
    ];

    return _mergeAddressParts(merged);
  }

  Map<String, String> _extractAlamatComponentsFromRawText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String grabAfterLabel(String line, String pattern) {
      return line
          .replaceAll(RegExp('$pattern\\s*[:\\-]?\\s*', caseSensitive: false), '')
          .trim();
    }

    String pickNextIfNeeded(int i, String current) {
      if (current.isNotEmpty) return current;
      if (i + 1 >= lines.length) return '';
      final next = lines[i + 1];
      if (_looksLikeFieldLabel(next)) return '';
      return next;
    }

    String alamat = '';
    String rtrw = '';
    String keldesa = '';
    String kecamatan = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      if (alamat.isEmpty && upper.contains('ALAMAT')) {
        alamat = pickNextIfNeeded(i, grabAfterLabel(line, r'ALAMAT'));
      }
      if (rtrw.isEmpty && (upper.contains('RT/RW') || (upper.contains('RT') && upper.contains('RW')))) {
        rtrw = pickNextIfNeeded(i, grabAfterLabel(line, r'RT\s*\/?\s*RW'));
      }
      if (keldesa.isEmpty &&
          (upper.contains('KEL/DESA') ||
              upper.contains('KELURAHAN') ||
              upper.contains('DESA'))) {
        keldesa = pickNextIfNeeded(
            i,
            grabAfterLabel(
                line, r'KEL\s*\/?\s*DESA|KELURAHAN|DESA'));
      }
      if (kecamatan.isEmpty && upper.contains('KECAMATAN')) {
        kecamatan = pickNextIfNeeded(i, grabAfterLabel(line, r'KECAMATAN'));
      }
    }

    return {
      'alamat': alamat,
      'rtrw': rtrw,
      'keldesa': keldesa,
      'kecamatan': kecamatan,
    };
  }

  String _mergeAddressParts(List<String> parts) {
    final unique = <String>[];
    for (final part in parts) {
      final cleaned = part
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (cleaned.isEmpty) continue;
      if (!unique.any((p) => p.toUpperCase() == cleaned.toUpperCase())) {
        unique.add(cleaned);
      }
    }
    return unique.join(', ');
  }

  void _applyParsedKTPData({
    required String nik,
    required String nama,
    required String alamat,
  }) {
    final normalizedNik = _normalizeNikValue(nik);
    bool anyFilled = false;
    setState(() {
      final currentNik = _nikCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (normalizedNik.isNotEmpty && currentNik != normalizedNik) {
        _nikCtrl.value = TextEditingValue(
          text: normalizedNik,
          selection: TextSelection.collapsed(offset: normalizedNik.length),
        );
        anyFilled = true;
      }
      if (nama.isNotEmpty && _namaCtrl.text.isEmpty) {
        _namaCtrl.text = nama;
        anyFilled = true;
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

  void _parseKTPText(String rawText) {
    // ── Normalisasi teks OCR ──────────────────────────────────────────────────
    // OCR sering salah baca karakter: 0↔O, 1↔I, dll.
    // Gabung semua baris menjadi satu string + pertahankan per-baris untuk parsing
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String nik = '';
    String nama = '';
    String alamat = '';

    // Helper: ekstrak nilai setelah label (contoh "NAMA : Budi" → "Budi")
    String _afterLabel(String line, String label) {
      return line
          .replaceAll(RegExp(label + r'\s*[:\-]?\s*', caseSensitive: false), '')
          .trim();
    }

    // Helper: cek apakah baris mengandung label, tapi ISI-nya ada di baris yg sama atau berikutnya
    String _extractValue(List<String> lines, int i, String label) {
      final after = _afterLabel(lines[i], label);
      if (after.length >= 2) return after;
      // Nilai di baris berikutnya (skip baris yang kelihatan seperti label lain)
      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        // Baris berikutnya bukan label KTP lain
        final isAnotherLabel = RegExp(
                r'^(NIK|NAMA|ALAMAT|RT|RW|KELURAHAN|KECAMATAN|AGAMA|STATUS|PEKERJAAN|KEWARGANEGARAAN|BERLAKU)',
                caseSensitive: false)
            .hasMatch(next);
        if (!isAnotherLabel && next.length >= 2) return next;
      }
      return '';
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineUpper = line.toUpperCase();

      // ── NIK ──────────────────────────────────────────────────────────────
      // KTP: NIK = 16 digit. OCR kadang sisipkan spasi (3201 0604 ...) atau
      // baca angka 0 sebagai O/o. Normalize dulu.
      if (nik.isEmpty) {
        // Ambil semua karakter digit dari baris (ganti O→0, I→1 di konteks angka)
        final digitOnly = line
            .replaceAll(RegExp(r'[Oo]'), '0')
            .replaceAll(RegExp(r'[Il]'), '1')
            .replaceAll(RegExp(r'[^\d]'), '');
        if (digitOnly.length == 16) {
          nik = digitOnly;
        } else if (lineUpper.contains('NIK')) {
          // Coba baris berikutnya
          if (i + 1 < lines.length) {
            final nextDigit = lines[i + 1]
                .replaceAll(RegExp(r'[Oo]'), '0')
                .replaceAll(RegExp(r'[Il]'), '1')
                .replaceAll(RegExp(r'[^\d]'), '');
            if (nextDigit.length == 16) nik = nextDigit;
          }
          // Fallback: ada 16 digit berurutan di baris ini (dengan separator)
          if (nik.isEmpty) {
            final m = RegExp(r'\d[\d\s\-]{14,}\d').firstMatch(line);
            if (m != null) {
              final cleaned = m.group(0)!.replaceAll(RegExp(r'\D'), '');
              if (cleaned.length == 16) nik = cleaned;
            }
          }
        }
      }

      // ── Nama ─────────────────────────────────────────────────────────────
      // Label bisa: "Nama", "NAMA", "Name" (salah baca)
      if (nama.isEmpty &&
          RegExp(r'^N[aA][mMnN][aAeE]', caseSensitive: false)
              .hasMatch(lineUpper)) {
        final val = _extractValue(lines, i, r'N[aA][mMnN][aAeE]');
        final normalizedName = _normalizeNameCandidate(val);
        if (normalizedName.isNotEmpty && !val.toUpperCase().contains('NIK')) {
          nama = normalizedName;
        }
      }

      // ── Alamat utama ─────────────────────────────────────────────────────
      if (alamat.isEmpty && lineUpper.contains('ALAMAT')) {
        final val = _extractValue(lines, i, r'ALAMAT');
        if (val.length >= 3) {
          alamat = val;
        }
      }
    }

    final rawAlamat = _extractAlamatComponentsFromRawText(rawText);
    final mergedAlamat = _mergeAddressParts([
      if (alamat.isNotEmpty) alamat,
      if ((rawAlamat['alamat'] ?? '').isNotEmpty) rawAlamat['alamat']!,
      if ((rawAlamat['rtrw'] ?? '').isNotEmpty) rawAlamat['rtrw']!,
      if ((rawAlamat['keldesa'] ?? '').isNotEmpty) rawAlamat['keldesa']!,
      if ((rawAlamat['kecamatan'] ?? '').isNotEmpty) rawAlamat['kecamatan']!,
    ]);

    if (mergedAlamat.isNotEmpty) {
      alamat = mergedAlamat;
    }

    _applyParsedKTPData(nik: nik, nama: nama, alamat: alamat);
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
        telepon: _teleponCtrl.text.trim(),
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
        if (_debugImageBytes != null) ...[
          const SizedBox(height: 14),
          _OCRDebugOverlayCard(
            imageBytes: _debugImageBytes!,
            imageSize: _debugImageSize,
            boxes: _debugBoxes,
          ),
        ],
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
        const SizedBox(height: 18),
        _SectionHeader(title: 'Data Kontak', icon: Icons.phone_outlined),
        const SizedBox(height: 12),
        _FormField(
          controller: _teleponCtrl,
          label: 'Nomor Telepon *',
          hint: '08xxxxxxxxxx',
          icon: Icons.phone_outlined,
          maxLength: 15,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
            LengthLimitingTextInputFormatter(15),
          ],
          validator: (v) => v?.trim().isEmpty ?? true ? 'Nomor telepon wajib diisi' : null,
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

class _KtpOcrLine {
  final String text;
  final Rect rect;

  const _KtpOcrLine({required this.text, required this.rect});
}

class _KtpDebugBox {
  final Rect rect;
  final Color color;
  final String label;
  final bool filled;
  final double strokeWidth;

  const _KtpDebugBox({
    required this.rect,
    required this.color,
    required this.label,
    this.filled = false,
    this.strokeWidth = 1.4,
  });
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

class _OCRDebugOverlayCard extends StatelessWidget {
  final Uint8List imageBytes;
  final Size? imageSize;
  final List<_KtpDebugBox> boxes;

  const _OCRDebugOverlayCard({
    required this.imageBytes,
    required this.imageSize,
    required this.boxes,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (imageSize != null && imageSize!.height > 0)
        ? imageSize!.width / imageSize!.height
        : 1.58;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug OCR Overlay',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kotak menunjukkan label dan area value yang dipakai parser.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(imageBytes, fit: BoxFit.cover),
                  CustomPaint(
                    painter: _OCRDebugOverlayPainter(
                      sourceSize: imageSize,
                      boxes: boxes,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _DebugLegendChip(color: Color(0xFF42A5F5), label: 'Label'),
              _DebugLegendChip(color: Color(0xFF26C6DA), label: 'Value'),
              _DebugLegendChip(color: Color(0xFFFFA726), label: 'Area'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugLegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _DebugLegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OCRDebugOverlayPainter extends CustomPainter {
  final Size? sourceSize;
  final List<_KtpDebugBox> boxes;

  _OCRDebugOverlayPainter({required this.sourceSize, required this.boxes});

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceSize == null || sourceSize!.width == 0 || sourceSize!.height == 0) {
      return;
    }

    final scaleX = size.width / sourceSize!.width;
    final scaleY = size.height / sourceSize!.height;

    for (final box in boxes) {
      final scaled = Rect.fromLTRB(
        box.rect.left * scaleX,
        box.rect.top * scaleY,
        box.rect.right * scaleX,
        box.rect.bottom * scaleY,
      );

      if (box.filled) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = box.color;
        canvas.drawRect(scaled, fillPaint);
      }

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = box.color
        ..strokeWidth = box.strokeWidth;
      canvas.drawRect(scaled, strokePaint);

      if (box.label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: box.label,
            style: TextStyle(
              color: box.color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          maxLines: 1,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: size.width - 8);

        final dy = (scaled.top - 12).clamp(2, size.height - 12).toDouble();
        final dx = (scaled.left + 2).clamp(2, size.width - 4).toDouble();
        textPainter.paint(canvas, Offset(dx, dy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OCRDebugOverlayPainter oldDelegate) {
    return oldDelegate.sourceSize != sourceSize || oldDelegate.boxes != boxes;
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