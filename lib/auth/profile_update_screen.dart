import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/models/user_profile.dart';
import 'package:trogo_app/prefs/app_preference.dart';

// Model moved to lib/models/user_profile.dart - remove local copy

class ProfileService {
  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<void> persistProfile(UserProfile profile) async {
    await AppPreference().setString(
      PreferencesKey.userName,
      profile.name,
    );
    await AppPreference().setString(
      PreferencesKey.userEmail,
      profile.email,
    );
    await AppPreference().setString(
      PreferencesKey.userMobile,
      profile.mobile,
    );
    await AppPreference().setString(
      PreferencesKey.userGender,
      profile.gender,
    );
    await AppPreference().setString(
      PreferencesKey.userProfileImage,
      profile.profileImage ?? '',
    );
  }

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
      ).timeout(_requestTimeout);

      print("⬅️ STATUS CODE => ${response.statusCode}");
      print("⬅️ RESPONSE => ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = UserProfile.fromJson(data['record']);
        await persistProfile(profile);
        return profile;
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
      return await updateProfileMultipart(
        token: token,
        name: name,
        email: email,
        password: password,
        mobile: mobile,
        gender: gender,
        profileImage: profileImage,
      );
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
    File? profileImage,
  }) async {
    try {
      final request = http.MultipartRequest('PUT', Uri.parse(profileUpdate));

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['mobile'] = mobile;
      request.fields['type'] = 'user';
      request.fields['gender'] = gender.toLowerCase();

      if (password.trim().isNotEmpty) {
        request.fields['password'] = password;
      }

      if (profileImage != null) {
        if (!_isSupportedProfileFile(profileImage.path)) {
          throw Exception(
            'Invalid file type. Only JPG, JPEG, PNG allowed.',
          );
        }
        final mediaType = _profileFileMediaType(profileImage.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'profileImage',
            profileImage.path,
            filename: p.basename(profileImage.path),
            contentType: mediaType,
          ),
        );
      }

      final response = await request.send().timeout(_requestTimeout);
      final responseBody = await response.stream.bytesToString();

      print("📥 MULTIPART STATUS => ${response.statusCode}");
      print("📥 MULTIPART BODY => $responseBody");

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final profile = UserProfile.fromJson(data['record']);
        await persistProfile(profile);
        return profile;
      } else {
        throw Exception(_extractApiErrorMessage(responseBody));
      }
    } catch (e) {
      throw Exception(_extractReadableError(e));
    }
  }
}

String _extractApiErrorMessage(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
  } catch (_) {}

  return 'Failed to update profile. Please try again.';
}

String _extractReadableError(Object error) {
  var message = error.toString();
  if (message.startsWith('Exception: ')) {
    message = message.substring('Exception: '.length);
  }

  const multipartPrefix = 'Multipart update error: ';
  if (message.startsWith(multipartPrefix)) {
    message = message.substring(multipartPrefix.length);
  }

  const profilePrefix = 'Profile update failed: ';
  if (message.startsWith(profilePrefix)) {
    message = message.substring(profilePrefix.length);
  }

  final separatorIndex = message.indexOf(' - {');
  if (separatorIndex != -1) {
    final jsonPart = message.substring(separatorIndex + 3);
    return _extractApiErrorMessage(jsonPart);
  }

  return message;
}

String _normalizeGenderValue(String? gender) {
  final value = gender?.trim().toLowerCase();
  switch (value) {
    case 'male':
      return 'male';
    case 'female':
      return 'female';
    case 'other':
      return 'other';
    default:
      return 'male';
  }
}

String _genderLabel(String? gender) {
  switch (_normalizeGenderValue(gender)) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    case 'other':
      return 'Other';
    default:
      return 'Male';
  }
}

bool _isSupportedProfileFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.pdf';
}

MediaType? _profileFileMediaType(String filePath) {
  switch (p.extension(filePath).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return MediaType('image', 'jpeg');
    case '.png':
      return MediaType('image', 'png');
    case '.pdf':
      return MediaType('application', 'pdf');
    default:
      return null;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    Key? key,
    this.navigateToHomeOnComplete = false,
    this.completionPageBuilder,
  }) : super(key: key);

  final bool navigateToHomeOnComplete;
  final WidgetBuilder? completionPageBuilder;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profileFuture;
  final ProfileService _profileService = ProfileService();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUpdating = false;
  bool _didAutoOpenEdit = false;

  // Form controllers for edit screen
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _selectedGender = 'male';
  final List<String> _genders = ['male', 'female', 'other'];

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
    _confirmPasswordController.dispose();
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _navigateToHomeAfterCompletion() async {
    if (!widget.navigateToHomeOnComplete ||
        widget.completionPageBuilder == null ||
        !mounted) {
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: widget.completionPageBuilder!),
      (route) => false,
    );
  }

  Future<void> _navigateToEditProfile(UserProfile profile) async {
    // Pre-fill the form with existing data
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _mobileController.text = profile.mobile;
    _selectedGender = _normalizeGenderValue(profile.gender);
    _passwordController.text = ''; // Leave password empty
    _confirmPasswordController.text = '';

    // Navigate to edit screen
    final updatedProfile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              nameController: _nameController,
              emailController: _emailController,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
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

      await _navigateToHomeAfterCompletion();
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

    if (_passwordController.text.trim().isNotEmpty &&
        _passwordController.text.trim() !=
            _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password and confirm password do not match'),
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
        password: _passwordController.text.trim(),
        mobile: _mobileController.text,
        gender: _normalizeGenderValue(_selectedGender),
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
          content: Text(_extractReadableError(e)),
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
            final shouldOpenEdit =
                !_didAutoOpenEdit &&
                (profile.name.trim().isEmpty || profile.email.trim().isEmpty);
            final size = MediaQuery.of(context).size;
            final shortestSide = size.shortestSide;
            final horizontalPadding =
                shortestSide < 360 ? 12.0 : shortestSide < 600 ? 16.0 : 24.0;
            final avatarSize =
                shortestSide < 360 ? 104.0 : shortestSide < 600 ? 120.0 : 136.0;
            final titleFontSize =
                shortestSide < 360 ? 22.0 : shortestSide < 600 ? 24.0 : 28.0;
            final subtitleFontSize =
                shortestSide < 360 ? 14.0 : shortestSide < 600 ? 16.0 : 17.0;

            if (shouldOpenEdit) {
              _didAutoOpenEdit = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                await _navigateToEditProfile(profile);
              });
            }

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: shortestSide < 360 ? 12 : 20),
                        SizedBox(
                          width: avatarSize,
                          height: avatarSize,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _buildProfileImage(profile),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          profile.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInfoCard('Mobile Number', profile.mobile, Icons.phone),
                        _buildInfoCard(
                          'Gender',
                          _genderLabel(profile.gender),
                          Icons.person,
                        ),
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
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _navigateToEditProfile(profile);
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
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
  final TextEditingController confirmPasswordController;
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
    required this.confirmPasswordController,
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
  final ProfileService _profileService = ProfileService();
  File? _tempSelectedImage;
  String? _tempSelectedGender;
  bool _isUpdating = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _tempSelectedImage = widget.selectedImage;
    _tempSelectedGender = _normalizeGenderValue(widget.selectedGender);
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

  Future<void> _saveProfile() async {
    if (_isUpdating) return;
    if (widget.nameController.text.trim().isEmpty ||
        widget.emailController.text.trim().isEmpty ||
        widget.mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.passwordController.text.trim().isNotEmpty &&
        widget.passwordController.text.trim() !=
            widget.confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password and confirm password do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_tempSelectedImage != null &&
          !_isSupportedProfileFile(_tempSelectedImage!.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG, JPEG, or PNG image is allowed'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final updatedProfile = await _profileService.updateProfile(
        name: widget.nameController.text.trim(),
        email: widget.emailController.text.trim(),
        password: widget.passwordController.text.trim(),
        mobile: widget.mobileController.text.trim(),
        gender: _normalizeGenderValue(_tempSelectedGender ?? widget.selectedGender),
        profileImage: _tempSelectedImage,
      );

      widget.onImageSelected(_tempSelectedImage);

      if (!mounted) return;
      Navigator.pop(context, updatedProfile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractReadableError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveProfile)],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(child: _buildProfileImage()),
                const SizedBox(height: 20),
                const Text(
                  'Update your profile picture by tapping on it',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                _buildTextField(
                  controller: widget.nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: widget.emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  isRequired: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: widget.mobileController,
                  label: 'Mobile Number',
                  icon: Icons.phone,
                  isRequired: false,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: widget.passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  isObscure: _isPasswordObscured,
                  onToggleObscure: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: widget.confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline,
                  isObscure: _isConfirmPasswordObscured,
                  onToggleObscure: () {
                    setState(() {
                      _isConfirmPasswordObscured =
                          !_isConfirmPasswordObscured;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildGenderDropdown(),
                const SizedBox(height: 30),
                _buildUpdateButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
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
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? ' *' : ''}',
        prefixIcon: Icon(icon, color: Colors.black),
        suffixIcon:
            onToggleObscure == null
                ? null
                : IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    isObscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade700,
                  ),
                ),
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
      isExpanded: true,
      value: _normalizeGenderValue(_tempSelectedGender),
      decoration: InputDecoration(
        labelText: 'Gender *',
        prefixIcon: Icon(Icons.person_outline, color: Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      borderRadius: BorderRadius.circular(14),
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87),
      items:
          widget.genders.map((String gender) {
            return DropdownMenuItem<String>(
              value: _normalizeGenderValue(gender),
              child: Text(
                _genderLabel(gender),
                overflow: TextOverflow.ellipsis,
              ),
            );
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
        onPressed: _isUpdating ? null : _saveProfile,
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
