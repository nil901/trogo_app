
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
// models/user_profile.dart
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String gender;
  final String? profileImage;
  final Location? location;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.gender,
    this.profileImage,
    this.location,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      gender: json['gender'] ?? '',
      profileImage: json['profileImage'],
      location: json['location'] != null 
          ? Location.fromJson(json['location'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Location {
  final String type;
  final List<double> coordinates;

  Location({
    required this.type,
    required this.coordinates,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      type: json['type'] ?? 'Point',
      coordinates: List<double>.from(json['coordinates'] ?? []),
    );
  }
}
class ProfileService {


 Future<UserProfile> fetchProfile() async {
  try {
    final token = AppPreference().getString(PreferencesKey.authToken);

    print("➡️ API URL => $profileGet");
    print("➡️ TOKEN => $token");

    if (token == null || token.isEmpty) {
      throw Exception("Auth token missing");
    }

    final response = await http.get(
      Uri.parse(profileGet),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print("⬅️ STATUS CODE => ${response.statusCode}");
    print("⬅️ RESPONSE => ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserProfile.fromJson(data['record']);
    } else {
      throw Exception(
        'Failed to load profile: ${response.statusCode} ${response.body}',
      );
    }
  } catch (e) {
    print("❌ API ERROR => $e");
    rethrow;
  }
}


  Future<String> updateProfileImage(String token, String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/auth/profile/image'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          imagePath,
        ),
      );

      var response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        return data['profileImageUrl'] ?? data['profileImage'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<UserProfile> updateProfile(String token, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data['record']);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }
}

class ProfileScreen extends StatefulWidget {


  const ProfileScreen({Key? key, }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profileFuture;
  final ProfileService _profileService = ProfileService();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.fetchProfile();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
     // await _uploadProfileImage();
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
      });
     // await _uploadProfileImage();
    }
  }

  // Future<void> _uploadProfileImage() async {
  //   if (_selectedImage == null) return;

  //   setState(() {
  //     _isUpdating = true;
  //   });

  //   try {
  //     final imageUrl = await _profileService.updateProfileImage(
  //       AppPreference().getInt(PreferencesKey.authToken),
  //       _selectedImage!.path,
  //     );

  //     // Refresh profile data
  //     setState(() {
  //       _profileFuture = _profileService.fetchProfile();
  //       _selectedImage = null;
  //       _isUpdating = false;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Profile picture updated successfully!'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //   } catch (e) {
  //     setState(() {
  //       _isUpdating = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to upload image: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  Widget _buildProfileImage(UserProfile profile) {
    return GestureDetector(
      onTap: () => _showImagePickerOptions(),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: ClipOval(
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover)
                  : profile.profileImage != null
                      ? Image.network(
                          profile.profileImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.person, size: 60, color: Colors.grey),
                        )
                      : Icon(Icons.person, size: 60, color: Colors.grey),
            ),
          ),
          if (_isUpdating)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text('Error loading profile'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _profileFuture = _profileService.fetchProfile();
                      });
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasData) {
            final profile = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 30),
                  Center(child: _buildProfileImage(profile)),
                  SizedBox(height: 20),
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    profile.email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 30),
                  _buildInfoCard('Mobile Number', profile.mobile, Icons.phone),
                  _buildInfoCard('Gender', profile.gender, Icons.person),
                  _buildInfoCard(
                    'Member Since',
                    '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
                    Icons.calendar_today,
                  ),
                  if (profile.location != null)
                    _buildInfoCard(
                      'Location',
                      '${profile.location!.coordinates[1]}, ${profile.location!.coordinates[0]}',
                      Icons.location_on,
                    ),
                  SizedBox(height: 40),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to edit profile screen
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          }

          return Center(child: Text('No profile data available'));
        },
      ),
    );
  }
}