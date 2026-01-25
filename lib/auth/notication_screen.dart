import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/auth/login_notifier.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await notifactionpesApi(ref);
    setState(() => isLoading = false);
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

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Notification deleted")));
      }
    } catch (e) {
      debugPrint("Delete notification error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notifactionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? const Center(child: Text("No notifications"))
              : ListView.builder(
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
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.message),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(item.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await deleteNotification(notificationId: item.id);
                        },
                      ),
                    ),
                  );
                },
              ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}-${date.month}-${date.year}";
  }
}
