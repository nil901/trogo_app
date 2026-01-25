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
      location:
          json['location'] != null ? Location.fromJson(json['location']) : null,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class Location {
  final String type;
  final List<double> coordinates;

  Location({required this.type, required this.coordinates});

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

  Future<UserProfile> updateProfile({
    required String name,
    required String email,
    required String password,
    required String mobile,
    required String gender,
    File? profileImage,
  }) async {
    try {
      final token = AppPreference().getString(PreferencesKey.authToken);

      if (token == null || token.isEmpty) {
        throw Exception("Auth token missing");
      }

      print("🔄 Starting profile update...");

      // If profile image is selected, use multipart request
      if (profileImage != null) {
        return await updateProfileMultipart(
          token: token,
          name: name,
          email: email,
          password: password,
          mobile: mobile,
          gender: gender,
          profileImage: profileImage,
        );
      } else {
        // Use regular JSON request for text-only updates
        return await updateProfileJson(
          token: token,
          name: name,
          email: email,
          password: password,
          mobile: mobile,
          gender: gender,
        );
      }
    } catch (e) {
      print("❌ Update error: $e");
      rethrow;
    }
  }

  Future<UserProfile> updateProfileMultipart({
    required String token,
    required String name,
    required String email,
    required String password,
    required String mobile,
    required String gender,
    required File profileImage,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/auth/profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Text fields
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['mobile'] = mobile;
      request.fields['type'] = 'user';
      request.fields['gender'] = gender;

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('profileImage', profileImage.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print("📥 MULTIPART STATUS => ${response.statusCode}");
      print("📥 MULTIPART BODY => $responseBody");

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return UserProfile.fromJson(data['record']);
      } else {
        throw Exception("Profile update failed: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Multipart update error: $e");
    }
  }

  Future<UserProfile> updateProfileJson({
    required String token,
    required String name,
    required String email,
    required String password,
    required String mobile,
    required String gender,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/profile');

      print("🔄 JSON Update URL: $url");
      print(
        "🔄 Update Data: name=$name, email=$email, mobile=$mobile, gender=$gender",
      );

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'mobile': mobile,
          'type': 'user',
          'gender': gender,
        }),
      );

      print("📥 JSON STATUS => ${response.statusCode}");
      print("📥 JSON BODY => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data['record']);
      } else {
        throw Exception(
          "JSON update failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("JSON update error: $e");
    }
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profileFuture;
  final ProfileService _profileService = ProfileService();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUpdating = false;

  // Form controllers for edit screen
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
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
    }
  }

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
              border: Border.all(color: Colors.black, width: 3),
            ),
            child: ClipOval(
              child:
                  _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : profile.profileImage != null
                      ? Image.network(
                        profile.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
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
                color: Colors.black,
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
      builder:
          (context) => SafeArea(
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
        leading: Icon(icon, color: Colors.black),
        title: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _navigateToEditProfile(UserProfile profile) async {
    // Pre-fill the form with existing data
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _mobileController.text = profile.mobile;
    _selectedGender = profile.gender;
    _passwordController.text = ''; // Leave password empty

    // Navigate to edit screen
    final updatedProfile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              nameController: _nameController,
              emailController: _emailController,
              passwordController: _passwordController,
              mobileController: _mobileController,
              selectedGender: _selectedGender,
              genders: _genders,
              profileImage: profile.profileImage,
              selectedImage: _selectedImage,
              onImageSelected: (File? image) {
                setState(() {
                  _selectedImage = image;
                });
              },
            ),
      ),
    );

    // If profile was updated, refresh the data
    if (updatedProfile != null && updatedProfile is UserProfile) {
      setState(() {
        _profileFuture = Future.value(updatedProfile);
        _selectedImage = null; // Reset selected image after update
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _mobileController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedProfile = await _profileService.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        password:
            _passwordController.text.isNotEmpty
                ? _passwordController.text
                : 'current_password', // Use current password if not changed
        mobile: _mobileController.text,
        gender: _selectedGender,
        profileImage: _selectedImage,
      );

      setState(() {
        _isUpdating = false;
      });

      // Return updated profile to previous screen
      Navigator.pop(context, updatedProfile);
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final profile = await _profileFuture;
              _navigateToEditProfile(profile);
            },
          ),
        ],
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    profile.email,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      onPressed: () async {
                        await _navigateToEditProfile(profile);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.black,
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

// Edit Profile Screen
class EditProfileScreen extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController mobileController;
  final String selectedGender;
  final List<String> genders;
  final String? profileImage;
  final File? selectedImage;
  final Function(File?) onImageSelected;

  const EditProfileScreen({
    Key? key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.mobileController,
    required this.selectedGender,
    required this.genders,
    this.profileImage,
    this.selectedImage,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _tempSelectedImage;
  String? _tempSelectedGender;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedImage = widget.selectedImage;
    _tempSelectedGender = widget.selectedGender;
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
        _tempSelectedImage = File(image.path);
      });
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
        _tempSelectedImage = File(photo.path);
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
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

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _showImagePickerOptions,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 3),
            ),
            child: ClipOval(
              child:
                  _tempSelectedImage != null
                      ? Image.file(_tempSelectedImage!, fit: BoxFit.cover)
                      : widget.profileImage != null
                      ? Image.network(
                        widget.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                      )
                      : Icon(Icons.person, size: 60, color: Colors.grey),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              // Pass the selected image back
              widget.onImageSelected(_tempSelectedImage);

              // Update the parent widget's gender selection
              widget.nameController.text = widget.nameController.text;
              widget.emailController.text = widget.emailController.text;
              widget.mobileController.text = widget.mobileController.text;

              // Trigger update in parent widget
              final _ProfileScreenState parentState =
                  context.findAncestorStateOfType<_ProfileScreenState>()!;
              await parentState._updateProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 20),
            Center(child: _buildProfileImage()),
            SizedBox(height: 20),
            Text(
              'Update your profile picture by tapping on it',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 30),
            _buildTextField(
              controller: widget.nameController,
              label: 'Full Name',
              icon: Icons.person,
              isRequired: true,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: widget.emailController,
              label: 'Email Address',
              icon: Icons.email,
              isRequired: true,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: widget.mobileController,
              label: 'Mobile Number',
              icon: Icons.phone,
              isRequired: false,

              keyboardType: TextInputType.phone,
            ), 
            SizedBox(height: 16),
            // _buildTextField(
            //   controller: widget.passwordController,
            //   label: 'Password (leave empty to keep current)',
            //   icon: Icons.lock,
            //   isObscure: true,
            // ),
            SizedBox(height: 16),
            // _buildGenderDropdown(),
            SizedBox(height: 30),
            // _buildUpdateButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? ' *' : ''}',
        prefixIcon: Icon(icon, color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _tempSelectedGender,
      decoration: InputDecoration(
        labelText: 'Gender *',
        prefixIcon: Icon(Icons.person_outline, color: Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      items:
          widget.genders.map((String gender) {
            return DropdownMenuItem<String>(value: gender, child: Text(gender));
          }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _tempSelectedGender = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select gender';
        }
        return null;
      },
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed:
            _isUpdating
                ? null
                : () async {
                  // Pass the selected image back
                  widget.onImageSelected(_tempSelectedImage);

                  // Update the parent widget's gender selection
                  widget.nameController.text = widget.nameController.text;
                  widget.emailController.text = widget.emailController.text;
                  widget.mobileController.text = widget.mobileController.text;

                  // Trigger update in parent widget
                  final _ProfileScreenState? parentState =
                      context.findAncestorStateOfType<_ProfileScreenState>();
                  if (parentState != null) {
                    await parentState._updateProfile();
                  }
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isUpdating
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                  'Update Profile',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
      ),
    );
  }
}
