import 'dart:convert';

enum NotificationType { announcement, alert, promo, update }

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.type = NotificationType.announcement,
    this.targetAudience = 'All Users',
    this.sentBy = 'Admin',
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final NotificationType type;
  final String targetAudience;
  final String sentBy;
  final bool read;

  AdminNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? sentAt,
    NotificationType? type,
    String? targetAudience,
    String? sentBy,
    bool? read,
  }) {
    return AdminNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      type: type ?? this.type,
      targetAudience: targetAudience ?? this.targetAudience,
      sentBy: sentBy ?? this.sentBy,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'type': type.name,
      'targetAudience': targetAudience,
      'sentBy': sentBy,
      'read': read,
    };
  }

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      sentAt: DateTime.tryParse(map['sentAt'] as String? ?? '') ?? DateTime.now(),
      type: NotificationType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => NotificationType.announcement,
      ),
      targetAudience: map['targetAudience'] as String? ?? 'All Users',
      sentBy: map['sentBy'] as String? ?? 'Admin',
      read: map['read'] as bool? ?? false,
    );
  }

  /// Row of the `broadcasts` table.
  factory AdminNotification.fromRow(Map<String, dynamic> row) {
    return AdminNotification(
      id: row['id'].toString(),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      sentAt: DateTime.tryParse(row['sent_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      type: NotificationType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => NotificationType.announcement,
      ),
      targetAudience: row['target_audience'] as String? ?? 'All Users',
      sentBy: row['sent_by'] as String? ?? 'Admin',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AdminNotification.fromJson(String source) =>
      AdminNotification.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
