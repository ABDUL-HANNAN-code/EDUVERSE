// File: lib/welcome.dart
// Welcome Role Selection Screen for Eduverse

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WelcomeRoleScreen extends StatefulWidget {
  const WelcomeRoleScreen({super.key});

  @override
  State<WelcomeRoleScreen> createState() => _WelcomeRoleScreenState();
}

class _WelcomeRoleScreenState extends State<WelcomeRoleScreen> {
  // 0 = None, 1 = Student, 2 = Recruiter
  int _selectedRole = 0;

  void _handleContinue() {
    if (_selectedRole == 1) {
      // Navigate to Student Login using GetX
      Get.toNamed('/login');
    } else if (_selectedRole == 2) {
      // Navigate to Recruiter Login using GetX
      Get.toNamed('/recruiter-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),
                
                const SizedBox(height: 60),
                
                // Header Text
                _buildHeader(),
                
                const SizedBox(height: 50),
                
                // Selection Cards
                _buildRoleCards(),
                
                const Spacer(),
                
                // Optional Settings Hint
                _buildSettingsHint(),
                
                const SizedBox(height: 16),
                
                // Continue Button
                _buildContinueButton(),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Eduverse",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              // Direct login - navigate to student login by default
              Get.toNamed('/login');
            },
            child: const Text(
              "Log In",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            children: [
              TextSpan(text: "Welcome to\nEduverse! "),
              TextSpan(text: "👋"),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "How are you planning to use the platform?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "(We'll customize your experience based on this)",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCards() {
    return Row(
      children: [
        Expanded(
          child: _buildRoleCard(
            id: 1,
            title: "I'm a Student",
            subtitle: "I want to find\njobs & learn",
            icon: Icons.school_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRoleCard(
            id: 2,
            title: "I'm a Recruiter",
            subtitle: "I want to hire\ntop talent",
            icon: Icons.business_center_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required int id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == id;
    const accentColor = Color(0xFF448AFF);

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade300,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isSelected ? accentColor : Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? accentColor : Colors.grey.shade800,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selection Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 6),
        Text(
          "You can change this later in settings",
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final isEnabled = _selectedRole != 0;
    const accentColor = Color(0xFF448AFF);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.2),
          disabledForegroundColor: Colors.white.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isEnabled ? 8 : 0,
          shadowColor: isEnabled ? accentColor.withOpacity(0.5) : null,
        ),
        child: const Text(
          "Continue",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}