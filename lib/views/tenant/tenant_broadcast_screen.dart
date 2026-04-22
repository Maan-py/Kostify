// lib/views/tenant/tenant_broadcast_screen.dart

import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../models/broadcast_model.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';

class TenantBroadcastScreen extends StatefulWidget {
  const TenantBroadcastScreen({super.key});

  @override
  State<TenantBroadcastScreen> createState() => _TenantBroadcastScreenState();
}

class _TenantBroadcastScreenState extends State<TenantBroadcastScreen> {
  final _auth = AuthController.to;
  final _db = DatabaseHelper();

  bool _isLoading = true;
  int _unreadCount = 0;
  List<BroadcastMessageModel> _broadcasts = [];

  @override
  void initState() {
    super.initState();
    _syncBroadcasts();
  }

  Future<void> _syncBroadcasts() async {
    final user = _auth.currentUser.value;
    if (user == null) return;

    setState(() => _isLoading = true);

    final undelivered = await _db.getUndeliveredBroadcasts(user.id!);
    for (final broadcast in undelivered) {
      await NotificationService.instance.showBroadcastNotification(
        title: broadcast.title,
        body: broadcast.message,
        payload: broadcast.id?.toString(),
      );
      await _db.markBroadcastDelivered(broadcast.id!, user.id!);
    }

    final inbox = await _db.getBroadcastInbox(user.id!);
    final unreadCount = await _db.getUnreadBroadcastCount(user.id!);

    if (!mounted) return;
    setState(() {
      _broadcasts = inbox;
      _unreadCount = unreadCount;
      _isLoading = false;
    });
  }

  Future<void> _openBroadcast(BroadcastMessageModel broadcast) async {
    final user = _auth.currentUser.value;
    if (user == null) return;

    await _db.markBroadcastRead(broadcast.id!, user.id!);
    await _syncBroadcasts();

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              broadcast.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Dikirim pada ${broadcast.createdAt.day.toString().padLeft(2, '0')}/${broadcast.createdAt.month.toString().padLeft(2, '0')}/${broadcast.createdAt.year}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Text(
              broadcast.message,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Broadcast Kos',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1BC0BA).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_unreadCount baru',
                  style: const TextStyle(
                    color: Color(0xFF1BC0BA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _syncBroadcasts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncBroadcasts,
        color: const Color(0xFF1BC0BA),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1BC0BA)))
            : _broadcasts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Belum ada broadcast dari admin.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _broadcasts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final broadcast = _broadcasts[index];
                      final unread = !broadcast.isRead;
                      return InkWell(
                        onTap: () => _openBroadcast(broadcast),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: unread
                                  ? const Color(0xFF1BC0BA)
                                  : const Color(0xFFE5E7EB),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: unread
                                      ? const Color(0xFF1BC0BA)
                                          .withOpacity(0.14)
                                      : const Color(0xFF8095E4)
                                          .withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  unread
                                      ? Icons.notifications_active_rounded
                                      : Icons.campaign_rounded,
                                  color: unread
                                      ? const Color(0xFF1BC0BA)
                                      : const Color(0xFF8095E4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            broadcast.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: unread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: const Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ),
                                        if (unread)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1BC0BA),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      broadcast.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${broadcast.createdAt.day.toString().padLeft(2, '0')}/${broadcast.createdAt.month.toString().padLeft(2, '0')}/${broadcast.createdAt.year}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
