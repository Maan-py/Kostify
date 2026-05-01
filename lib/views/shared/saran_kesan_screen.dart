// lib/views/shared/saran_kesan_screen.dart

import 'package:flutter/material.dart';

class SaranKesanScreen extends StatefulWidget {
  const SaranKesanScreen({super.key});

  @override
  State<SaranKesanScreen> createState() => _SaranKesanScreenState();
}

class _SaranKesanScreenState extends State<SaranKesanScreen> {
  // Data hardcoded mata kuliah TPM
  static const _mataKuliah = 'Teknologi Pemrograman Mobile (TPM)';
  static const _dosen =
      'Bagus Muhammad Akbar, S.ST., M.Kom'; // Ganti sesuai dosen asli
  static const _semester = 'Semester Genap 2025/2026';

  // Pesan kesan dan saran yang statis (hard-coded)
  static const _kesanStatis =
      'Mata kuliah ini sangat bermanfaat untuk mempelajari dasar-dasar pemrograman mobile. Materi yang disampaikan cukup komprehensif dan praktik yang dilakukan membantu pemahaman.';
  static const _saranStatis =
      'Tingkatkan lebih banyak sesi praktik dan berikan lebih banyak studi kasus real-world. Bantuan dari asisten juga bisa ditingkatkan agar lebih responsif.';

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
                border:
                    Border.all(color: const Color(0xFF8095E4).withOpacity(0.2)),
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

            // Kesan (Read-only)
            const _FieldLabel(text: 'Kesan terhadap mata kuliah TPM'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _kesanStatis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Saran (Read-only)
            const _FieldLabel(text: 'Saran untuk mata kuliah TPM'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _saranStatis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper ────────────────────────────────────────────────────────────────────

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
