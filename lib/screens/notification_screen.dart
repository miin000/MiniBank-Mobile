import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/notification_api.dart';
import '../auth/auth_storage.dart';

class NotificationScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const NotificationScreen({super.key, required this.baseUrl, required this.storage});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late NotificationApi _api;
  NotificationSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = NotificationApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _api.getSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification item) async {
    if (!item.unread) return;
    await _api.markRead(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _summary?.notifications ?? const <AppNotification>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : items.isEmpty
                  ? const Center(child: Text('Chưa có thông báo nào'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return InkWell(
                            onTap: () => _markRead(item),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: item.unread ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: item.unread ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                                    child: Icon(Icons.notifications_rounded, color: item.unread ? const Color(0xFF2563EB) : Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 6),
                                        Text(item.content, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
                                        if (item.createdAt != null) ...[
                                          const SizedBox(height: 8),
                                          Text(item.createdAt!.toLocal().toString().split('.').first, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
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