// lib/views/admin/admin_broadcast_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/auth_controller.dart';
import '../../models/broadcast_model.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _db = DatabaseHelper();
  final _auth = AuthController.to;
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _isSending = false;
  List<BroadcastMessageModel> _broadcasts = [];

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBroadcasts() async {
    final items = await _db.getAllBroadcasts(limit: 30);
    if (mounted) {
      setState(() => _broadcasts = items);
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul dan isi broadcast harus diisi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final admin = _auth.currentUser.value;
      final broadcast = BroadcastMessageModel(
        title: title,
        message: message,
        audience: 'tenant',
        createdByUserId: admin?.id,
        createdByName: admin?.namaLengkap ?? admin?.username ?? 'Admin',
        createdAt: DateTime.now(),
      );

      final insertedId = await _db.createBroadcast(broadcast);
      if (insertedId <= 0) {
        throw Exception('Broadcast gagal disimpan.');
      }

      await NotificationService.instance.showBroadcastNotification(
        title: 'Broadcast terkirim',
        body: title,
        payload: insertedId.toString(),
      );

      _titleCtrl.clear();
      _messageCtrl.clear();
      await _loadBroadcasts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Broadcast berhasil dibuat untuk seluruh tenant.'),
          backgroundColor: Color(0xFF1BC0BA),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Broadcast Tenant',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadBroadcasts,
        color: const Color(0xFF8095E4),
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8095E4), Color(0xFF5F73C8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kirim pengumuman ke semua tenant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Broadcast akan disimpan sebagai pengumuman kos dan ditampilkan di inbox tenant.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: const InputDecoration(
                labelText: 'Judul Broadcast',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageCtrl,
              maxLength: AppConstants.MAX_SARAN_LENGTH,
              minLines: 5,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(AppConstants.MAX_SARAN_LENGTH)
              ],
              decoration: const InputDecoration(
                labelText: 'Isi Broadcast',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendBroadcast,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.campaign_rounded),
                label: Text(_isSending ? 'Mengirim...' : 'Kirim Broadcast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8095E4),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Riwayat Broadcast',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_broadcasts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text('Belum ada broadcast yang dikirim.'),
              )
            else
              ..._broadcasts.map(
                (broadcast) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BroadcastHistoryCard(broadcast: broadcast),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastHistoryCard extends StatelessWidget {
  final BroadcastMessageModel broadcast;

  const _BroadcastHistoryCard({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8095E4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Color(0xFF8095E4), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      broadcast.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      broadcast.createdByName == null
                          ? 'Tenant'
                          : 'Dibuat oleh ${broadcast.createdByName}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${broadcast.createdAt.day.toString().padLeft(2, '0')}/${broadcast.createdAt.month.toString().padLeft(2, '0')}/${broadcast.createdAt.year}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            broadcast.message,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
