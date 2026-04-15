// lib/views/admin/admin_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _api = ApiService();
  final _db = DatabaseHelper();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  final List<Map<String, String>> _chatHistory = [];

  // Konteks sistem untuk Gemini (rekap data kos)
  String _systemContext = '';

  @override
  void initState() {
    super.initState();
    _loadContext();
    _addWelcome();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final stats = await _db.getDashboardStats();
    final tenants = await _db.getAllTenants();

    _systemContext = '''
Kamu adalah KosBot, asisten AI untuk sistem manajemen kos bernama Kostify.
Data kos saat ini:
- Nama kos: ${AppConstants.KOS_NAME}
- Alamat: ${AppConstants.KOS_ADDRESS}
- Total penghuni: ${stats['total_tenant']}
- Penghuni aktif: ${stats['tenant_aktif']}
- Penghuni nonaktif: ${stats['tenant_nonaktif']}
- Pendapatan bulan ${stats['bulan']}: ${AppValidators.formatRupiah(stats['pendapatan_bulan_ini'] as int? ?? 0)}
- Tagihan pending bulan ini: ${stats['tagihan_pending']}
Jawab pertanyaan admin seputar manajemen kos, rekap data, atau saran pengelolaan kos. 
Gunakan Bahasa Indonesia yang ramah dan profesional.
''';
  }

  void _addWelcome() {
    _messages.add(_ChatMessage(
      text: 'Halo Admin! Saya KosBot 🏠\n\nSaya siap membantu kamu dengan:\n'
          '• Rekap data penghuni & pembayaran\n'
          '• Analisis pendapatan kos\n'
          '• Saran manajemen kos\n'
          '• Menjawab pertanyaan seputar Kostify\n\n'
          'Ada yang bisa saya bantu?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();

    // Validasi
    final error = AppValidators.validateChatMessage(text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    if (_isLoading) return;

    _msgCtrl.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    // Tambah ke history
    _chatHistory.add({'role': 'user', 'content': text});

    final result = await _api.sendToGemini(
      text,
      chatHistory: _chatHistory.length > 2
          ? _chatHistory.sublist(0, _chatHistory.length - 1)
          : null,
      systemContext: _systemContext,
    );

    if (!mounted) return;

    if (result.success) {
      _chatHistory.add({'role': 'assistant', 'content': result.text!});
      setState(() {
        _messages.add(_ChatMessage(
          text: result.text!,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } else {
      _chatHistory.removeLast();
      setState(() {
        _messages.add(_ChatMessage(
          text: '⚠️ ${result.error ?? 'Terjadi kesalahan. Coba lagi.'}',
          isUser: false,
          isError: true,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Quick action prompts
  final _quickPrompts = const [
    '📊 Rekap pendapatan bulan ini',
    '👥 Siapa saja yang belum bayar?',
    '💡 Saran meningkatkan hunian kos',
    '📋 Rangkum data penghuni aktif',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF8095E4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF8095E4), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KosBot AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Powered by Gemini', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
            tooltip: 'Reset chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _chatHistory.clear();
                _addWelcome();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) return _buildTypingIndicator();
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),

          // Quick prompts (tampil hanya kalau belum banyak pesan)
          if (_messages.length <= 2)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _quickPrompts.map((prompt) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _msgCtrl.text = prompt.replaceAll(RegExp(r'^[\p{Emoji}\s]+', unicode: true), '').trim();
                      _sendMessage();
                    },
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF8095E4)),
                    labelStyle: const TextStyle(color: Color(0xFF8095E4)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                )).toList(),
              ),
            ),

          // Input area
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
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(AppConstants.MAX_CHAT_LENGTH),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Tanya sesuatu...',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F6FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? const Color(0xFF8095E4).withOpacity(0.5)
                            : const Color(0xFF8095E4),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _TypingDot(delay: i * 150)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: message.isError
                    ? Colors.red.shade50
                    : const Color(0xFF8095E4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                message.isError ? Icons.warning_rounded : Icons.smart_toy_rounded,
                size: 16,
                color: message.isError ? Colors.red : const Color(0xFF8095E4),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF8095E4)
                    : message.isError
                        ? Colors.red.shade50
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? Colors.red.shade200
                            : const Color(0xFFE5E7EB),
                      ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    required this.timestamp,
  });
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: Color(0xFF8095E4),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
