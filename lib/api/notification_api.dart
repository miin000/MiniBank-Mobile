import 'dart:convert';

import 'authed_api.dart';

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String content;
  final String status;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  bool get unread => status.toUpperCase() == 'UNREAD';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? 'SYSTEM').toString(),
      title: (json['title'] ?? 'Thông báo').toString(),
      content: (json['content'] ?? '').toString(),
      status: (json['status'] ?? 'UNREAD').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class NotificationSummary {
  final int unreadCount;
  final List<AppNotification> notifications;

  const NotificationSummary({required this.unreadCount, required this.notifications});

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['notifications'];
    return NotificationSummary(
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      notifications: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(AppNotification.fromJson).toList()
          : const [],
    );
  }
}

class NotificationApi {
  final AuthedApi api;

  const NotificationApi({required this.api});

  Future<NotificationSummary> getSummary() async {
    final res = await api.get('/api/mobile/notifications').timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Không tải được thông báo');
    }
    return NotificationSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> markRead(int id) async {
    final res = await api.patch('/api/mobile/notifications/$id/read').timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : 'Không cập nhật được thông báo');
    }
  }
}