import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final _uuid = const Uuid();

  // Initialize FCM permissions and message listeners
  Future<void> initializeFCM() async {
    // Request permission (needed on iOS & Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Background FCM triggers automatically log history
    });

    // Listen to notifications clicked in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Trigger navigation when user taps notification banner
    });
  }

  // Log a new notification to Firestore history (which acts as a fallback feed)
  Future<void> sendNotification({
    required String title,
    required String body,
    required String userId,
    String type = 'general',
  }) async {
    final id = _uuid.v4();
    final notif = NotificationModel(
      id: id,
      title: title,
      body: body,
      userId: userId,
      isRead: false,
      timestamp: DateTime.now(),
      type: type,
    );

    await _db.collection('notifications').doc(id).set(notif.toMap());
  }

  // Get notification feed stream for a specific user
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => NotificationModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
