// lib/views/tenant/tools_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'flappy_bird_screen.dart';
import '../admin/admin_chat_screen.dart'; // Reuse chat bubble component

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Tools', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8095E4),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF8095E4),
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.currency_exchange_rounded, size: 18), text: 'Kurs'),
            Tab(icon: Icon(Icons.access_time_rounded, size: 18), text: 'Waktu'),
            Tab(icon: Icon(Icons.smart_toy_rounded, size: 18), text: 'AI'),
            Tab(icon: Icon(Icons.sports_esports_rounded, size: 18), text: 'Game'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CurrencyConverterTab(),
          _TimeConverterTab(),
          _TenantChatTab(),
          _GameTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Konversi Mata Uang ────────────────────────────────────────────────

class _CurrencyConverterTab extends StatefulWidget {
  const _CurrencyConverterTab();

  @override
  State<_CurrencyConverterTab> createState() => _CurrencyConverterTabState();
}

class _CurrencyConverterTabState extends State<_CurrencyConverterTab> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();

  String _fromCurrency = 'IDR';
  String _toCurrency = 'USD';
  Map<String, double> _rates = {};
  bool _isLoading = false;
  String? _error;
  double? _result;
  DateTime? _lastFetch;

  final _currencies = AppConstants.SUPPORTED_CURRENCIES;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    setState(() { _isLoading = true; _error = null; });

    final result = await _api.getExchangeRates(_fromCurrency);

    if (mounted) {
      if (result.success) {
        setState(() {
          _rates = result.rates!;
          _lastFetch = DateTime.now();
          _isLoading = false;
        });
        _convert();
      } else {
        setState(() { _error = result.error; _isLoading = false; });
      }
    }
  }

  void _convert() {
    final amountStr = _amountCtrl.text.trim().replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _result = null);
      return;
    }

    if (_fromCurrency == _toCurrency) {
      setState(() => _result = amount);
      return;
    }

    if (_rates.containsKey(_toCurrency)) {
      setState(() => _result = amount * _rates[_toCurrency]!);
    } else {
      _fetchRates();
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _rates = {};
      _result = null;
    });
    if (_amountCtrl.text.isNotEmpty) _fetchRates();
  }

  String _getSymbol(String code) {
    return _currencies.firstWhere((c) => c['code'] == code,
        orElse: () => {'symbol': code})['symbol']!;
  }

  String _formatResult(double value, String currency) {
    if (currency == 'IDR' || currency == 'JPY') {
      return NumberFormat('#,##0', 'id_ID').format(value.round());
    }
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Amount input
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jumlah', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        onChanged: (_) => _convert(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: '0',
                          counterText: '',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                        ),
                      ),
                    ),
                    _CurrencyDropdown(
                      value: _fromCurrency,
                      currencies: _currencies,
                      onChanged: (v) => setState(() { _fromCurrency = v!; _rates = {}; _result = null; }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Swap button
          Center(
            child: GestureDetector(
              onTap: _swapCurrencies,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8095E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Hasil Konversi', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ),
                    _CurrencyDropdown(
                      value: _toCurrency,
                      currencies: _currencies,
                      onChanged: (v) => setState(() { _toCurrency = v!; _result = null; }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF8095E4)))
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: Colors.orange.shade700, fontSize: 12))
                else
                  Text(
                    _result != null
                        ? '${_getSymbol(_toCurrency)} ${_formatResult(_result!, _toCurrency)}'
                        : '--',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Convert button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchRates,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Perbarui Kurs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8095E4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_lastFetch != null) ...[
            const SizedBox(height: 10),
            Text(
              'Kurs diperbarui: ${DateFormat('HH:mm').format(_lastFetch!)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Daftar kurs semua mata uang
          if (_rates.isNotEmpty) _RatesTable(rates: _rates, baseCurrency: _fromCurrency),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final List<Map<String, String>> currencies;
  final ValueChanged<String?> onChanged;
  const _CurrencyDropdown({required this.value, required this.currencies, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      borderRadius: BorderRadius.circular(12),
      items: currencies.map((c) => DropdownMenuItem(
        value: c['code'],
        child: Text('${c['code']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

class _RatesTable extends StatelessWidget {
  final Map<String, double> rates;
  final String baseCurrency;
  const _RatesTable({required this.rates, required this.baseCurrency});

  @override
  Widget build(BuildContext context) {
    final supportedCodes = AppConstants.SUPPORTED_CURRENCIES.map((c) => c['code']!).toList();
    final displayRates = rates.entries
        .where((e) => supportedCodes.contains(e.key) && e.key != baseCurrency)
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1 $baseCurrency setara dengan:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          ...displayRates.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text(
                  e.value >= 1000
                      ? NumberFormat('#,##0.##', 'en_US').format(e.value)
                      : e.value.toStringAsFixed(4),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Tab 2: Konversi Waktu ────────────────────────────────────────────────────

class _TimeConverterTab extends StatefulWidget {
  const _TimeConverterTab();

  @override
  State<_TimeConverterTab> createState() => _TimeConverterTabState();
}

class _TimeConverterTabState extends State<_TimeConverterTab> {
  DateTime _selectedTime = DateTime.now();
  String _fromTZ = 'WIB';

  final _timezones = AppConstants.TIMEZONES;

  // Offset dalam jam relatif ke UTC
  int _getOffset(String tzId) {
    switch (tzId) {
      case 'WIB': return 7;
      case 'WITA': return 8;
      case 'WIT': return 9;
      case 'London': return _isLondonBST() ? 1 : 0;
      default: return 7;
    }
  }

  bool _isLondonBST() {
    // BST (British Summer Time) berlaku dari akhir Maret sampai akhir Oktober
    final now = DateTime.now();
    return now.month >= 4 && now.month <= 10;
  }

  DateTime _convertTime(String toTZ) {
    final fromOffset = _getOffset(_fromTZ);
    final toOffset = _getOffset(toTZ);
    final utc = _selectedTime.subtract(Duration(hours: fromOffset));
    return utc.add(Duration(hours: toOffset));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF8095E4)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = DateTime(
          _selectedTime.year, _selectedTime.month, _selectedTime.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final fmtDate = DateFormat('EEEE, d MMM yyyy', 'id_ID');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Waktu referensi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8095E4), Color(0xFF6B7FD7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Waktu Referensi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickTime,
                  child: Text(
                    fmt.format(_selectedTime),
                    style: const TextStyle(color: Colors.white, fontSize: 52,
                        fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                ),
                Text(fmtDate.format(_selectedTime),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                // Pilih zona asal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButton<String>(
                    value: _fromTZ,
                    dropdownColor: const Color(0xFF8095E4),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    items: _timezones.map((tz) => DropdownMenuItem(
                      value: tz['id'],
                      child: Text(tz['id']!),
                    )).toList(),
                    onChanged: (v) => setState(() => _fromTZ = v!),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white70),
                  label: const Text('Ubah Waktu', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hasil konversi
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Konversi ke semua zona waktu',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E))),
          ),
          const SizedBox(height: 10),

          ..._timezones
              .where((tz) => tz['id'] != _fromTZ)
              .map((tz) {
            final converted = _convertTime(tz['id']!);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tz['id']!,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                              color: Color(0xFF1A1A2E))),
                      Text(tz['name']!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(converted),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: Color(0xFF8095E4)),
                      ),
                      Text(
                        'UTC${tz['offset']!.startsWith('+') || tz['offset']!.startsWith('-') ? '' : '+'}${tz['offset']}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Tab 3: AI Chat Tenant ────────────────────────────────────────────────────

class _TenantChatTab extends StatefulWidget {
  const _TenantChatTab();

  @override
  State<_TenantChatTab> createState() => _TenantChatTabState();
}

class _TenantChatTabState extends State<_TenantChatTab> {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_SimpleChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  bool _isLoading = false;

  static const _systemCtx = '''
Kamu adalah KosBot, asisten AI untuk penghuni kos Kostify.
Alamat kos: ${AppConstants.KOS_ADDRESS}.
Bantu penghuni dengan informasi aturan kos, tips tinggal di kos, informasi umum, 
pertanyaan tentang lokasi kos, dan hal-hal umum lainnya.
Gunakan Bahasa Indonesia yang ramah dan santai.
''';

  @override
  void initState() {
    super.initState();
    _messages.add(_SimpleChatMessage(
      text: 'Halo! Saya KosBot 🏠\nAda yang bisa saya bantu seputar kos atau hal lainnya?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || text.length > AppConstants.MAX_CHAT_LENGTH || _isLoading) return;
    _msgCtrl.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_SimpleChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scroll();

    _history.add({'role': 'user', 'content': text});
    final result = await _api.sendToGemini(text, chatHistory: _history.length > 2 ? _history.sublist(0, _history.length - 1) : null, systemContext: _systemCtx);

    if (!mounted) return;
    if (result.success) {
      _history.add({'role': 'assistant', 'content': result.text!});
      setState(() { _messages.add(_SimpleChatMessage(text: result.text!, isUser: false)); _isLoading = false; });
    } else {
      _history.removeLast();
      setState(() { _messages.add(_SimpleChatMessage(text: '⚠️ ${result.error}', isUser: false, isError: true)); _isLoading = false; });
    }
    _scroll();
  }

  void _scroll() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: Text('...', style: TextStyle(fontSize: 20, color: Color(0xFF8095E4))),
                    ),
                  ]),
                );
              }
              final msg = _messages[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: msg.isUser ? const Color(0xFF8095E4) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                          ),
                          border: msg.isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(msg.text,
                            style: TextStyle(
                              color: msg.isUser ? Colors.white : const Color(0xFF1A1A2E),
                              fontSize: 14, height: 1.5,
                            )),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLength: AppConstants.MAX_CHAT_LENGTH,
                    maxLines: 3, minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.MAX_CHAT_LENGTH)],
                    decoration: InputDecoration(
                      hintText: 'Tanya sesuatu...',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true, fillColor: const Color(0xFFF5F6FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isLoading ? const Color(0xFF8095E4).withOpacity(0.5) : const Color(0xFF8095E4),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: _isLoading
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  _SimpleChatMessage({required this.text, required this.isUser, this.isError = false});
}

// ─── Tab 4: Game ──────────────────────────────────────────────────────────────

class _GameTab extends StatelessWidget {
  const _GameTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mini Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 6),
          const Text('Hiburan untuk penghuni kos',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 24),
          _GameCard(
            title: 'Flappy Kost',
            description: 'Bantu burung melewati pipa! Kontrol dengan tap atau gyroscope ponsel.',
            emoji: '🐦',
            badge1: '👆 Tap',
            badge2: '📱 Gyro',
            color: const Color(0xFF8095E4),
            onPlay: () => Get.to(() => const FlappyBirdScreen(),
                transition: Transition.downToUp,
                duration: const Duration(milliseconds: 300)),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String description;
  final String emoji;
  final String badge1;
  final String badge2;
  final Color color;
  final VoidCallback onPlay;

  const _GameCard({
    required this.title,
    required this.description,
    required this.emoji,
    required this.badge1,
    required this.badge2,
    required this.color,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Badge(label: badge1, color: color),
                        const SizedBox(width: 6),
                        _Badge(label: badge2, color: const Color(0xFF1BC0BA)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Mulai Main', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
