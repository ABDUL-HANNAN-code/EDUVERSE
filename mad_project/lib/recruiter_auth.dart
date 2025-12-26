// File: lib/timetable/PLACEMENTS/recruiter_auth.dart
// Complete Recruiter Authentication Screen with Login & Sign Up

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'timetable/PLACEMENTS/recruiter_admin_panel.dart';

// ==================== AUTHENTICATION CONTROLLER ====================

class RecruiterAuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxBool isLoading = false.obs;
  RxBool isLogin = true.obs; // true = Login, false = Sign Up

  // Controllers
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();
  
  final signupFullNameController = TextEditingController();
  final signupCompanyController = TextEditingController();
  final signupEmailController = TextEditingController();
  final signupPhoneController = TextEditingController();
  final signupPasswordController = TextEditingController();
  final signupConfirmPasswordController = TextEditingController();

  // Observable states
  RxBool obscureLoginPassword = true.obs;
  RxBool obscureSignupPassword = true.obs;
  RxBool obscureConfirmPassword = true.obs;
  RxBool acceptTerms = false.obs;

  @override
  void onClose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    signupFullNameController.dispose();
    signupCompanyController.dispose();
    signupEmailController.dispose();
    signupPhoneController.dispose();
    signupPasswordController.dispose();
    signupConfirmPasswordController.dispose();
    super.onClose();
  }

  // Toggle between Login and Sign Up
  void toggleAuthMode() {
    isLogin.value = !isLogin.value;
  }

  // ==================== LOGIN ====================
  Future<void> login() async {
    if (loginEmailController.text.trim().isEmpty ||
        loginPasswordController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter both email and password',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
      return;
    }

    isLoading.value = true;

    try {
      // Sign in with Firebase
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: loginEmailController.text.trim(),
        password: loginPasswordController.text,
      );

      // Check if user is a recruiter
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        Get.snackbar(
          'Error',
          'User not found. Please sign up first.',
          backgroundColor: Colors.red.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoading.value = false;
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      if (userData['role'] != 'recruiter') {
        await _auth.signOut();
        Get.snackbar(
          'Access Denied',
          'This portal is for recruiters only',
          backgroundColor: Colors.red.shade100,
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoading.value = false;
        return;
      }

      // Update last login
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({'lastLoginAt': FieldValue.serverTimestamp()});

      // Success - Navigate to Dashboard
      Get.snackbar(
        'Success',
        'Welcome back, ${userData['fullName'] ?? 'Recruiter'}!',
        backgroundColor: Colors.green.shade100,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );

      Get.offAll(() => const RecruiterAdminPanel());
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Login Failed',
        _getErrorMessage(e.code),
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An unexpected error occurred: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== SIGN UP ====================
  Future<void> signUp() async {
    // Validation
    if (signupFullNameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter your full name',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    if (signupCompanyController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter your company name',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    if (signupEmailController.text.trim().isEmpty ||
        !signupEmailController.text.contains('@')) {
      Get.snackbar('Error', 'Please enter a valid email',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    if (signupPasswordController.text.length < 6) {
      Get.snackbar('Error', 'Password must be at least 6 characters',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    if (signupPasswordController.text != signupConfirmPasswordController.text) {
      Get.snackbar('Error', 'Passwords do not match',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    if (!acceptTerms.value) {
      Get.snackbar('Error', 'Please accept the terms and conditions',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    isLoading.value = true;

    try {
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: signupEmailController.text.trim(),
        password: signupPasswordController.text,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': signupEmailController.text.trim(),
        'fullName': signupFullNameController.text.trim(),
        'companyName': signupCompanyController.text.trim(),
        'phoneNumber': signupPhoneController.text.trim(),
        'role': 'recruiter',
        'isActive': true,
        'isApproved': true,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'photoUrl': null,
        'totalJobsPosted': 0,
        'totalApplicantsReceived': 0,
      });

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Success
      Get.snackbar(
        'Success',
        'Account created successfully! Please verify your email.',
        backgroundColor: Colors.green.shade100,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );

      // Navigate to Dashboard
      Get.offAll(() => const RecruiterAdminPanel());
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Sign Up Failed',
        _getErrorMessage(e.code),
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An unexpected error occurred: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== FORGOT PASSWORD ====================
  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      Get.snackbar('Error', 'Please enter a valid email',
          backgroundColor: Colors.orange.shade100);
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      Get.snackbar(
        'Success',
        'Password reset link sent to your email',
        backgroundColor: Colors.green.shade100,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Error',
        _getErrorMessage(e.code),
        backgroundColor: Colors.red.shade100,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Error message helper
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}

// ==================== MAIN AUTH SCREEN ====================

class RecruiterAuthScreen extends StatelessWidget {
  const RecruiterAuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RecruiterAuthController());

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E0D48), // Deep Purple
              Color(0xFF1A052E), // Darker Purple/Black
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Logo/Icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.business_center_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Title
                        const Text(
                          'Recruiter Portal',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Obx(() => Text(
                              controller.isLogin.value
                                  ? 'Sign in to access your dashboard'
                                  : 'Create your recruiter account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            )),
                        const SizedBox(height: 40),

                        // Auth Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Obx(() => controller.isLogin.value
                              ? _buildLoginForm(controller)
                              : _buildSignUpForm(controller)),
                        ),

                        const SizedBox(height: 24),

                        // Toggle between Login and Sign Up
                        Obx(() => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  controller.isLogin.value
                                      ? "Don't have an account? "
                                      : 'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 15,
                                  ),
                                ),
                                TextButton(
                                  onPressed: controller.toggleAuthMode,
                                  child: Text(
                                    controller.isLogin.value
                                        ? 'Sign Up'
                                        : 'Login',
                                    style: const TextStyle(
                                      color: Color(0xFF448AFF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LOGIN FORM ====================
  Widget _buildLoginForm(RecruiterAuthController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to continue',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 30),

        // Email Field
        _buildTextField(
          controller: controller.loginEmailController,
          label: 'Email Address',
          hint: 'your.email@company.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        // Password Field
        Obx(() => _buildTextField(
              controller: controller.loginPasswordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscureText: controller.obscureLoginPassword.value,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureLoginPassword.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => controller.obscureLoginPassword.toggle(),
              ),
            )),
        const SizedBox(height: 12),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showForgotPasswordDialog(controller),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Color(0xFF448AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Login Button
        Obx(() => SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: controller.isLoading.value ? null : controller.login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF448AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            )),
      ],
    );
  }

  // ==================== SIGN UP FORM ====================
  Widget _buildSignUpForm(RecruiterAuthController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fill in your details to get started',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        // Full Name
        _buildTextField(
          controller: controller.signupFullNameController,
          label: 'Full Name',
          hint: 'John Doe',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),

        // Company Name
        _buildTextField(
          controller: controller.signupCompanyController,
          label: 'Company Name',
          hint: 'Tech Corp Inc.',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),

        // Email
        _buildTextField(
          controller: controller.signupEmailController,
          label: 'Work Email',
          hint: 'your.email@company.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Phone (Optional)
        _buildTextField(
          controller: controller.signupPhoneController,
          label: 'Phone Number (Optional)',
          hint: '+92 300 1234567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Password
        Obx(() => _buildTextField(
              controller: controller.signupPasswordController,
              label: 'Password',
              hint: 'Min 6 characters',
              icon: Icons.lock_outline,
              obscureText: controller.obscureSignupPassword.value,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureSignupPassword.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => controller.obscureSignupPassword.toggle(),
              ),
            )),
        const SizedBox(height: 16),

        // Confirm Password
        Obx(() => _buildTextField(
              controller: controller.signupConfirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter password',
              icon: Icons.lock_outline,
              obscureText: controller.obscureConfirmPassword.value,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.obscureConfirmPassword.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => controller.obscureConfirmPassword.toggle(),
              ),
            )),
        const SizedBox(height: 20),

        // Terms Checkbox
        Obx(() => Row(
              children: [
                Checkbox(
                  value: controller.acceptTerms.value,
                  onChanged: (value) =>
                      controller.acceptTerms.value = value ?? false,
                  activeColor: const Color(0xFF448AFF),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        controller.acceptTerms.value = !controller.acceptTerms.value,
                    child: Text(
                      'I accept the Terms of Service and Privacy Policy',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            )),
        const SizedBox(height: 24),

        // Sign Up Button
        Obx(() => SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: controller.isLoading.value ? null : controller.signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF448AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            )),
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF448AFF),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog(RecruiterAuthController controller) {
    final emailController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address to receive a password reset link'),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.resetPassword(emailController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF448AFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}