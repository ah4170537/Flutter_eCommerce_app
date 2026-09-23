import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloudinary_service.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import '../role_selection/role_selection_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoadingProfile = true;
  bool _isUploadingImage = false;

  String _name = '';
  String _email = '';
  String? _profileImageUrl;

  String _phone = '';
  String _secondaryPhone = '';
  String _country = '';
  String _state = '';
  String _city = '';
  String _postalCode = '';
  String _address = '';
  Map<String, dynamic> _rawUserData = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final data = doc.data()!;
      _rawUserData = data;
      final User? authUser = FirebaseAuth.instance.currentUser;
      final shipping = data['shippingAddress'] as Map<String, dynamic>?;

      setState(() {
        _name = data['name'] ?? data['fullName'] ?? authUser?.displayName ?? '';
        _email = data['email'] ?? authUser?.email ?? '';
        _profileImageUrl = data['profileImageUrl'] as String?;

        if (shipping != null) {
          _phone = (shipping['phone'] ?? '').toString();
          _secondaryPhone = (shipping['secondaryPhone'] ?? '').toString();
          _country = (shipping['country'] ?? '').toString();
          _state = (shipping['state'] ?? '').toString();
          _city = (shipping['city'] ?? '').toString();
          _postalCode = (shipping['postalCode'] ?? '').toString();
          _address = (shipping['address'] ?? '').toString();
        }

        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _navigateToEditScreen() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userId: widget.userId,
          initialData: {
            'name': _name,
            'email': _email,
            'shippingAddress': _rawUserData['shippingAddress'],
          },
        ),
      ),
    );

    if (updated == true) {
      _loadUserProfile();
    }
  }

  // Fungsi untuk membersihkan cache dan menukar peranan
  Future<void> _switchRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Mengosongkan cache/SharedPreferences[cite: 5]

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error switching role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menukar peranan: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showImageOptionsSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (_profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.primaryDark),
                title: const Text('View photo'),
                onTap: () => Navigator.pop(context, 'view'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primaryDark),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryDark),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'view') {
      _viewProfilePicture();
    } else if (action == 'camera') {
      await _pickAndUploadImage(ImageSource.camera);
    } else if (action == 'gallery') {
      await _pickAndUploadImage(ImageSource.gallery);
    }
  }

  void _viewProfilePicture() {
    if (_profileImageUrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(_profileImageUrl!),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
      );

      if (picked == null) return;

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppColors.primaryDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() => _isUploadingImage = true);

      final imageFile = File(croppedFile.path);
      final uploadedUrl = await CloudinaryService.uploadImage(
        imageFile,
        folder: 'profile_avatars',
      );

      if (uploadedUrl == null) throw Exception('Upload returned no URL');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'profileImageUrl': uploadedUrl}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _profileImageUrl = uploadedUrl;
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture updated'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _showImageOptionsSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? Icon(Icons.person, size: 56, color: Colors.grey.shade400)
                : null,
          ),
          if (_isUploadingImage)
            Positioned.fill(
              child: CircleAvatar(
                radius: 56,
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_pin_outlined, color: AppColors.primaryDark, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _navigateToEditScreen,
                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryDark),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryDark.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Personal Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(_InfoRow(Icons.badge_outlined, 'Full Name', _name)),
          _buildInfoRow(_InfoRow(Icons.email_outlined, 'Email', _email)),
          _buildInfoRow(_InfoRow(Icons.phone_outlined, 'Primary Phone', _phone)),
          _buildInfoRow(_InfoRow(Icons.phone_android_outlined, 'Secondary Phone', _secondaryPhone)),
          const SizedBox(height: 10),
          const Text(
            'Shipping Address',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(_InfoRow(Icons.public_outlined, 'Country', _country)),
          _buildInfoRow(_InfoRow(Icons.map_outlined, 'State', _state)),
          _buildInfoRow(_InfoRow(Icons.location_city_outlined, 'City', _city)),
          _buildInfoRow(_InfoRow(Icons.local_post_office_outlined, 'Postal Code', _postalCode)),
          _buildInfoRow(_InfoRow(Icons.home_outlined, 'Address', _address)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(row.icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  row.value.isNotEmpty ? row.value : 'Not set',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: row.value.isNotEmpty
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ],
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
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 14),
                    Text(
                      _name.isNotEmpty ? _name : 'No name set',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email.isNotEmpty ? _email : 'No email set',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildUnifiedDetailsCard(),
                    const SizedBox(height: 16),
                    
                    // BUTANG TUKAR PERANAN (SWITCH ROLE) DI TAMBAH DI SINI
                    ElevatedButton.icon(
                      onPressed: _switchRole,
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text(
                        'Switch App / Role',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;

  _InfoRow(this.icon, this.label, this.value);
}