import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reclaimify/theme_colors.dart';

// // Color Palette
// const Color kPrimaryColor = Color(0xFF6C63FF);
// const Color kSecondaryColor = Color(0xFF4A90E2);
// const Color kBackgroundColor = Color(0xFFF5F7FA);
// const Color kWhiteColor = Colors.white;
// const Color kDarkTextColor = Color(0xFF2D3142);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _isLoading = true;

  Map<String, dynamic>? _userData;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;
        final docSnapshot = await _firestore.collection('users').doc(_userId).get();
        if (docSnapshot.exists) {
          setState(() {
            _userData = docSnapshot.data();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          Get.snackbar(
            'Error',
            'User data not found',
            backgroundColor: Colors.red,
            colorText: kWhiteColor,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load user data: $e',
        backgroundColor: Colors.red,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      });
    } catch (e) {
      debugPrint('Failed to load preferences: $e');
    }
  }

  Future<void> _saveNotificationPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
      Get.snackbar(
        'Success',
        'Notification preferences updated',
        backgroundColor: kPrimaryColor,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save preferences: $e',
        backgroundColor: Colors.red,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _saveDarkModePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode_enabled', value);
      Get.snackbar(
        'Success',
        'Dark mode preferences updated',
        backgroundColor: kPrimaryColor,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save preferences: $e',
        backgroundColor: Colors.red,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _userData?['name'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWhiteColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kDarkTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.poppins(color: kDarkTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(color: kDarkTextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                Get.snackbar(
                  'Error',
                  'Name cannot be empty',
                  backgroundColor: Colors.red,
                  colorText: kWhiteColor,
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              try {
                await _firestore.collection('users').doc(_userId).update({
                  'name': newName,
                });

                setState(() {
                  _userData?['name'] = newName;
                });

                Get.back();
                Get.snackbar(
                  'Success',
                  'Profile updated successfully',
                  backgroundColor: kPrimaryColor,
                  colorText: kWhiteColor,
                  snackPosition: SnackPosition.BOTTOM,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to update profile: $e',
                  backgroundColor: Colors.red,
                  colorText: kWhiteColor,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(color: kWhiteColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        await _auth.sendPasswordResetEmail(email: user.email!);
        Get.snackbar(
          'Success',
          'Password reset email sent to ${user.email}',
          backgroundColor: kPrimaryColor,
          colorText: kWhiteColor,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send password reset email: $e',
        backgroundColor: Colors.red,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to logout: $e',
        backgroundColor: Colors.red,
        colorText: kWhiteColor,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'University ID copied to clipboard',
      backgroundColor: kPrimaryColor,
      colorText: kWhiteColor,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kDarkTextColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kDarkTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: kPrimaryColor,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  _buildProfileHeader(),
                  const SizedBox(height: 20),

                  // Account Information Section
                  _buildAccountInformation(),
                  const SizedBox(height: 16),

                  // Settings Section
                  _buildSettingsSection(),
                  const SizedBox(height: 16),

                  // Support & Legal Section
                  _buildSupportSection(),
                  const SizedBox(height: 16),

                  // Logout Button
                  _buildLogoutButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? _auth.currentUser?.email ?? 'No email';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: kPrimaryColor.withOpacity(0.2),
                child: Text(
                  _getInitials(name),
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryColor,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showEditProfileDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: kWhiteColor, width: 3),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: kWhiteColor,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: kDarkTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInformation() {
    final role = _userData?['role'] ?? 'N/A';
    final universityId = _userData?['universityId'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: kWhiteColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Information',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kDarkTextColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Role',
                value: role,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                label: 'University ID',
                value: universityId,
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: kSecondaryColor),
                  onPressed: () => _copyToClipboard(universityId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: kSecondaryColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: kDarkTextColor,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: kWhiteColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kDarkTextColor,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: kSecondaryColor),
              title: Text(
                'Notifications',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: kDarkTextColor,
                ),
              ),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveNotificationPreference(value);
                },
                activeColor: kPrimaryColor,
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined, color: kSecondaryColor),
              title: Text(
                'Dark Mode',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: kDarkTextColor,
                ),
              ),
              trailing: Switch(
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  _saveDarkModePreference(value);
                },
                activeColor: kPrimaryColor,
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: kSecondaryColor),
              title: Text(
                'Change Password',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: kDarkTextColor,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: _resetPassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: kWhiteColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Support & Legal',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kDarkTextColor,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: kSecondaryColor),
              title: Text(
                'Help & Support',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: kDarkTextColor,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Get.snackbar(
                  'Help & Support',
                  'Contact us at support@eduverse.com',
                  backgroundColor: kPrimaryColor,
                  colorText: kWhiteColor,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: kSecondaryColor),
              title: Text(
                'Privacy Policy',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: kDarkTextColor,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Get.snackbar(
                  'Privacy Policy',
                  'Visit our website for more details',
                  backgroundColor: kPrimaryColor,
                  colorText: kWhiteColor,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: kWhiteColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: kDarkTextColor,
                  ),
                ),
                content: Text(
                  'Are you sure you want to logout?',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: kDarkTextColor,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(color: kWhiteColor),
                    ),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: kWhiteColor),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kWhiteColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}