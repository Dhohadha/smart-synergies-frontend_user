import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_synergies/models/notification_model.dart';

class LocalNotificationService {
  static const String _notificationsKey = 'local_notifications';
  static const int _maxRetention = 200; // keep latest 200

  /// Save a notification to local storage
  static Future<void> saveNotification(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing notifications
      final List<NotificationModel> notifications = await getNotifications();

      // Check if notification with same ID already exists
      final existingIndex = notifications.indexWhere(
        (n) => n.id == notification.id,
      );

      if (existingIndex >= 0) {
        // Replace existing notification
        notifications[existingIndex] = notification;
      } else {
        // Add new notification
        notifications.add(notification);
      }

      // Sort notifications by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (notifications.length > _maxRetention) {
        notifications.removeRange(_maxRetention, notifications.length);
      }

      // Convert to JSON and save
      final List<String> notificationJsonList = notifications
          .map((n) => jsonEncode(n.toMap()))
          .toList();

      await prefs.setStringList(_notificationsKey, notificationJsonList);
      debugPrint('Notification saved successfully: ${notification.id}');
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Get all notifications from local storage
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure we have latest data from background isolate
      final notificationJsonList = prefs.getStringList(_notificationsKey) ?? [];

      return notificationJsonList
          .map((jsonStr) => NotificationModel.fromMap(jsonDecode(jsonStr)))
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.id == notificationId);

      if (index >= 0) {
        final updatedNotification = notifications[index].copyWith(isRead: true);
        notifications[index] = updatedNotification;

        final prefs = await SharedPreferences.getInstance();
        final notificationJsonList = notifications
            .map((n) => jsonEncode(n.toMap()))
            .toList();

        await prefs.setStringList(_notificationsKey, notificationJsonList);
        debugPrint('Notification marked as read: $notificationId');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final notificationJsonList = updatedNotifications
          .map((n) => jsonEncode(n.toMap()))
          .toList();

      await prefs.setStringList(_notificationsKey, notificationJsonList);
      debugPrint('All notifications marked as read');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == notificationId);

      final prefs = await SharedPreferences.getInstance();
      final notificationJsonList = notifications
          .map((n) => jsonEncode(n.toMap()))
          .toList();

      await prefs.setStringList(_notificationsKey, notificationJsonList);
      debugPrint('Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_notificationsKey, []);
      debugPrint('All notifications cleared');
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}

