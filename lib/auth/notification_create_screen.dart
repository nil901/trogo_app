// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:trogo_app/api_service/api_service.dart';
// import 'package:trogo_app/api_service/urls.dart';
// import 'package:trogo_app/models/notification_model.dart'; // Import your notification model

// class NotificationCreateScreen extends ConsumerStatefulWidget {
//   const NotificationCreateScreen({super.key});

//   @override
//   ConsumerState<NotificationCreateScreen> createState() => _NotificationCreateScreenState();
// }

// // ==================== API FUNCTION FOR CREATING NOTIFICATION ====================
// Future<void> createNotificationApi(WidgetRef ref, {
//   required String title,
//   required String message,
//   required String type,
// }) async {
//   try {
//     // Using the notificationCreate endpoint from urls.dart
//     // Make sure you have this constant defined in your urls.dart file
//     final response = await ApiService().postRequest(notificationCreate, {
//       "title": title,
//       "message": message,
//       "type": type,
//     });

//     if (response != null && response.statusCode == 200) {
//       debugPrint("Notification created successfully");
      
//       // Optionally refresh the notification list in your provider
//       // You can call your fetch notifications function here if needed
//       // await notifactionpesApi(ref);
      
//       return response.data;
//     } else {
//       throw Exception("Failed to create notification: ${response?.statusCode}");
//     }
//   } catch (e) {
//     debugPrint("Error creating notification: $e");
//     rethrow;
//   }
// }

// class _NotificationCreateScreenState extends ConsumerState<NotificationCreateScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _titleController = TextEditingController();
//   final _messageController = TextEditingController();
//   String _type = 'All'; // Default
//   bool _isLoading = false;

//   final List<String> _types = ['All', 'Passenger', 'Driver', 'System'];

//   Future<void> _createNotification() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       await createNotificationApi(
//         ref, 
//         title: _titleController.text.trim(), 
//         message: _messageController.text.trim(), 
//         type: _type,
//       );

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Notification created successfully!')),
//         );
//         Navigator.pop(context, true); // Return true to indicate success
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Notification'),
//         elevation: 2,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Title Field
//               TextFormField(
//                 controller: _titleController,
//                 decoration: const InputDecoration(
//                   labelText: 'Title',
//                   hintText: 'Enter notification title',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.title),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Title is required';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
              
//               // Message Field
//               TextFormField(
//                 controller: _messageController,
//                 decoration: const InputDecoration(
//                   labelText: 'Message',
//                   hintText: 'Enter notification message',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.message),
//                 ),
//                 maxLines: 3,
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Message is required';
//                   }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
              
//               // Type Dropdown
//               DropdownButtonFormField<String>(
//                 value: _type,
//                 decoration: const InputDecoration(
//                   labelText: 'Notification Type',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.category),
//                 ),
//                 items: _types.map((type) => DropdownMenuItem(
//                   value: type,
//                   child: Text(type),
//                 )).toList(),
//                 onChanged: (value) => setState(() => _type = value ?? 'All'),
//               ),
//               const SizedBox(height: 24),
              
//               // Create Button
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _createNotification,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: _isLoading
//                     ? const SizedBox(
//                         height: 20,
//                         width: 20,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Text(
//                         'Create Notification',
//                         style: TextStyle(fontSize: 16),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }