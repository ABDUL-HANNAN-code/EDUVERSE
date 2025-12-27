import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_marketplace.dart';

// Complaints views
import 'complaints/views/student_complaint_view.dart';
import 'complaints/views/create_complaint_screen.dart';
import 'complaints/views/admin_complaint_list.dart';

import 'shared.dart'; 
import 'auth.dart'; 
import 'lost_and_found.dart'; 
import 'timetable/index.dart'; 
import 'homepage/index.dart'; 
import 'homepage/admin_dashboard.dart';

// AI Study Planner module
import 'ai_study_planner/ai_study_planner.dart';

// Placement module
import 'timetable/placements/student_placement_screen.dart';
import 'timetable/placements/recruiter_admin_panel.dart';

// FACULTY DASHBOARD IMPORT (Preserved from your local changes)
import 'timetable/FACULTY/faculty_dashboard.dart'; 
import 'timetable/FACULTY/student_connect.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, s) {
    final msg = e.toString();
    if (msg.contains('already exists') || msg.contains('firebase app') && msg.contains('already')) {
      // swallow duplicate initialization error
    } else {
      runApp(ErrorReportApp(exception: e, stack: s));
      return;
    }
  }
  
  // Disable persistence for web compatibility
  try {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } catch (e) {}

  // Log recruiter creds if available (Debug only)
  try {
    final recruiterEmail = Platform.environment['RECRUITER_ADMIN_EMAIL'] ?? 'recruiter@admin.test';
    final recruiterPassword = Platform.environment['RECRUITER_ADMIN_PASSWORD'] ?? 'Recruiter123!';
    debugPrint('RECRUITER_ADMIN_CREDENTIALS:');
    debugPrint('  email: $recruiterEmail');
    debugPrint('  password: $recruiterPassword');
  } catch (_) {}
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('An error occurred',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(details.exceptionAsString()),
                const SizedBox(height: 12),
                Text(details.stack.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const UniversityApp());
}

class ErrorReportApp extends StatelessWidget {
  final Object exception;
  final StackTrace stack;
  const ErrorReportApp({super.key, required this.exception, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      home: Scaffold(
        appBar: AppBar(title: const Text('Init Error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Firebase initialization failed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(exception.toString()),
                const SizedBox(height: 12),
                Text(stack.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UniversityApp extends StatelessWidget {
  const UniversityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392, 803),
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Eduverse',
          // Kept 'Inter' from your local config. Change to 'Poppins' if you prefer the remote style.
          theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter'),

          home: const AuthGate(),

          getPages: [
            GetPage(name: '/login', page: () => const LoginView()),
            GetPage(name: '/dashboard', page: () => const HomeDashboard()), 
            GetPage(name: '/admin', page: () => const AdminDashboard()),
            GetPage(name: '/lost-and-found', page: () => const LostAndFoundLandingPage()), 
            GetPage(name: '/timetable', page: () => const TimetableScreen()), 
            GetPage(name: '/marketplace', page: () => const StudentMarketplace()),
            GetPage(name: '/complaints', page: () => StudentComplaintView()),
            GetPage(name: '/complaints/create', page: () => const CreateComplaintScreen()),
            GetPage(name: '/complaints/admin', page: () => AdminComplaintList()),
            GetPage(name: '/ai-study-planner', page: () => const StudyPlannerModule()),
            
            // Placement module
            GetPage(name: '/student-placement', page: () => const StudentPlacementScreen()),
            GetPage(name: '/recruiter-dashboard', page: () => const RecruiterAdminPanel()),

            // Faculty Module (Preserved)
            GetPage(name: '/faculty-dashboard', page: () => const FacultyDashboardScreen()),
            GetPage(name: '/faculty-connect', page: () => const MainNavigationScreen()),
          ],
        );
      },
    );
  }
}

// AuthGate with Role-Based Routing (Preserved)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if(!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final role = userData?['role'] ?? 'student';

          // Route based on role
          if (role == 'faculty') return const FacultyDashboardScreen();
          if (role == 'recruiter') return const RecruiterAdminPanel();
          if (role == 'admin') return const AdminDashboard();
          
          return user.emailVerified 
              ? const HomeDashboard() 
              : const VerifyEmailView();
        }
      );
    }
    
    return const LoginView();
  }
}