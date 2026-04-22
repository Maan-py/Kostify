// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _timeout = const Duration(seconds: AppConstants.HTTP_TIMEOUT_SECONDS);

  // ─── Connectivity ──────────────────────────────────────────────────────────

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Gemini AI ─────────────────────────────────────────────────────────────

  Future<GeminiResult> sendToGemini(
    String message, {
    List<Map<String, String>>? chatHistory,
    String? systemContext,
  }) async {
    if (!await hasInternet()) {
      return GeminiResult.error('Tidak ada koneksi internet.');
    }

    if (AppConstants.GEMINI_API_KEY == 'MISSING_API_KEY') {
      return GeminiResult.error(
        'API Key Gemini belum dikonfigurasi. Hubungi administrator.',
      );
    }

    try {
      // Susun riwayat percakapan
      final contents = <Map<String, dynamic>>[];

      // System context (jika ada)
      if (systemContext != null) {
        contents.add({
          'role': 'user',
          'parts': [
            {
              'text':
                  'Kamu adalah asisten manajemen kos bernama KosBot. $systemContext'
            }
          ],
        });
        contents.add({
          'role': 'model',
          'parts': [
            {
              'text':
                  'Baik, saya siap membantu sebagai asisten manajemen kos Kostify!'
            }
          ],
        });
      }

      // Riwayat chat (batasi 10 pesan terakhir untuk hemat token)
      if (chatHistory != null) {
        final limited = chatHistory.length > 10
            ? chatHistory.sublist(chatHistory.length - 10)
            : chatHistory;
        for (final msg in limited) {
          contents.add({
            'role': msg['role'] == 'user' ? 'user' : 'model',
            'parts': [
              {'text': msg['content'] ?? ''}
            ],
          });
        }
      }

      // Pesan baru
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });

      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.GEMINI_BASE_URL}?key=${AppConstants.GEMINI_API_KEY}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': contents,
              'generationConfig': {
                'maxOutputTokens': 1024,
                'temperature': 0.7,
              },
              'safetySettings': [
                {
                  'category': 'HARM_CATEGORY_HARASSMENT',
                  'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
                },
                {
                  'category': 'HARM_CATEGORY_HATE_SPEECH',
                  'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
                },
              ],
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text == null || text.toString().isEmpty) {
          return GeminiResult.error('Tidak ada respons dari AI. Coba lagi.');
        }
        return GeminiResult.success(text.toString().trim());
      } else if (response.statusCode == 429) {
        return GeminiResult.error(
            'Batas permintaan AI tercapai. Coba lagi dalam beberapa menit.');
      } else if (response.statusCode == 403) {
        return GeminiResult.error(
            'API Key tidak valid. Hubungi administrator.');
      } else {
        return GeminiResult.error(
            'Layanan AI sementara tidak tersedia (${response.statusCode}).');
      }
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return GeminiResult.error(
            'Koneksi ke AI timeout. Periksa internet dan coba lagi.');
      }
      return GeminiResult.error('Terjadi kesalahan. Coba lagi.');
    }
  }

  // ─── Telegram ──────────────────────────────────────────────────────────────

  Future<bool> sendTelegramAlert({
    required String tenantName,
    required String nomorKamar,
    required DateTime timestamp,
  }) async {
    print("DEBUG SOS: Token = ${AppConstants.TELEGRAM_BOT_TOKEN}");
    print("DEBUG SOS: ChatID = ${AppConstants.TELEGRAM_CHAT_ID}");
    if (!await hasInternet()) return false;

    if (AppConstants.TELEGRAM_BOT_TOKEN == 'MISSING_BOT_TOKEN' ||
        AppConstants.TELEGRAM_CHAT_ID == 'MISSING_CHAT_ID') {
      return false;
    }

    final message = '''
🚨 *PERINGATAN DARURAT KOSTIFY* 🚨

👤 Penghuni: *${_escapeTg(tenantName)}*
🚪 Kamar: *${_escapeTg(nomorKamar.isNotEmpty ? nomorKamar : '-')}*
📍 Lokasi: ${AppConstants.KOS_NAME}
⏰ Waktu: ${_formatDateTime(timestamp)}

⚠️ Penghuni mengirim sinyal darurat. Segera periksa!
''';

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.TELEGRAM_BASE_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': AppConstants.TELEGRAM_CHAT_ID,
              'text': message,
              'parse_mode': 'Markdown',
            }),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// WhatsApp Direct Message untuk reminder pembayaran
  Future<bool> sendPaymentReminder({
    required String tenantName,
    required String nomorHP,
    required String bulan,
    required int amount,
  }) async {
    if (nomorHP.isEmpty) return false;

    final formattedPhone = _formatPhoneNumber(nomorHP);
    final message = 'Halo $tenantName, ini pengingat pembayaran kost bulan $bulan sebesar Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}. Mohon segera diselesaikan ya, terima kasih!';
    final url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── Exchange Rate ─────────────────────────────────────────────────────────

  Future<ExchangeRateResult> getExchangeRates(String baseCurrency) async {
    if (!await hasInternet()) {
      return ExchangeRateResult.error('Tidak ada koneksi internet.');
    }

    if (AppConstants.EXCHANGE_RATE_API_KEY == 'MISSING_API_KEY') {
      return ExchangeRateResult.error(
        'API Key nilai tukar belum dikonfigurasi.',
      );
    }

    try {
      final url = '${AppConstants.EXCHANGE_RATE_BASE_URL}$baseCurrency';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'success') {
          final rates = Map<String, double>.from(
            (data['conversion_rates'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
          return ExchangeRateResult.success(rates);
        }
        return ExchangeRateResult.error('Data kurs tidak tersedia.');
      } else {
        return ExchangeRateResult.error(
            'Gagal mengambil data kurs (${response.statusCode}).');
      }
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return ExchangeRateResult.error('Timeout saat mengambil data kurs.');
      }
      return ExchangeRateResult.error('Terjadi kesalahan jaringan.');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _escapeTg(String text) {
    return text
        .replaceAll('*', '\\*')
        .replaceAll('_', '\\_')
        .replaceAll('`', '\\`');
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} WIB';
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer(); // Mulai dari string kosong
    int counter = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      counter++;
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      return '62${phone.substring(1)}';
    }
    return phone;
  }
}

// ─── Result Classes ────────────────────────────────────────────────────────────

class GeminiResult {
  final bool success;
  final String? text;
  final String? error;

  GeminiResult._({required this.success, this.text, this.error});

  factory GeminiResult.success(String text) =>
      GeminiResult._(success: true, text: text);

  factory GeminiResult.error(String error) =>
      GeminiResult._(success: false, error: error);
}

class ExchangeRateResult {
  final bool success;
  final Map<String, double>? rates;
  final String? error;

  ExchangeRateResult._({required this.success, this.rates, this.error});

  factory ExchangeRateResult.success(Map<String, double> rates) =>
      ExchangeRateResult._(success: true, rates: rates);

  factory ExchangeRateResult.error(String error) =>
      ExchangeRateResult._(success: false, error: error);
}
