import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';

// ==================== NOTIFICATION MODEL ====================
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// ==================== NOTIFICATION PROVIDER ====================
final notifactionProvider = StateProvider<List<NotificationModel>>((ref) {
  return [];
});

// ==================== API FUNCTION ====================
Future<void> notifactionpesApi(WidgetRef ref) async {
  try {
    final response = await ApiService().getRequest(notificationList);
    //  print(response!.data);
    if (response != null && response.statusCode == 200) {
      final data = response.data;
      
      if (data != null && data['notifications'] != null) {
        List<NotificationModel> notifications = [];
        
        for (var item in data['notifications']) {
          notifications.add(NotificationModel.fromJson(item));
        }
        
        // Sort by createdAt date (newest first)
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        ref.read(notifactionProvider.notifier).state = notifications;
      }
    }
  } catch (e) {
    debugPrint("Error fetching notifications: $e");
    rethrow;
  }
}

// ==================== NOTIFICATION SCREEN ====================
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      await notifactionpesApi(ref);
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load notifications";
      });
      debugPrint("Load notifications error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 🔴 DELETE API + Riverpod update
  Future<void> deleteNotification({required String notificationId}) async {
    try {
      final response = await ApiService().postRequest(noticationDelete, {
        "notificationId": notificationId,
      });

      if (response != null && response.statusCode == 200) {
        final list = [...ref.read(notifactionProvider)];
        list.removeWhere((e) => e.id == notificationId);
        ref.read(notifactionProvider.notifier).state = list;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notification deleted")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete notification")),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete notification error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notifactionProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
         backgroundColor: Colors.white,
        title: const Text("Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: 
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshNotifications,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "No notifications",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];

                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await deleteNotification(notificationId: item.id);
                      },
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications,
                          color: Colors.black,
                          size: 20,
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.message),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  item.type,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: item.type == 'All' 
                                        ? Colors.blue 
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await deleteNotification(notificationId: item.id);
                          },
                        ),
                        onTap: () {
                          _showNotificationDetails(item);
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }

  void _showNotificationDetails(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 16),
            Text(
              "Type: ${notification.type}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              "Received: ${_formatDateTime(notification.createdAt)}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      return "${date.day}-${date.month}-${date.year}";
    }
  }

  String _formatDateTime(DateTime date) {
    return "${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}