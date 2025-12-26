import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_marketplace.dart';
// Complaints views
import 'complaints/views/student_complaint_view.dart';
import 'complaints/views/create_complaint_screen.dart';
import 'complaints/views/admin_complaint_list.dart';

import 'shared.dart'; // Import Shared components
import 'auth.dart'; // Import Auth logic
import 'lost_and_found.dart'; // Import the Module
import 'timetable/index.dart'; // Import Timetable Module
import 'homepage/index.dart'; // Import Home Dashboard Module
import 'homepage/admin_dashboard.dart';
// AI Study Planner module
import 'ai_study_planner/ai_study_planner.dart';
// Placement module (student & recruiter)
import 'timetable/PLACEMENTS/student_placement_screen.dart';
import 'timetable/PLACEMENTS/recruiter_admin_panel.dart';
import 'recruiter_auth.dart';
// Welcome screen
import 'timetable/welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with your project credentials (guarded)
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBdgmYim3IN5UmNUo3LPlDHdLEkt_WEXys",
        appId: "1:772886464594:web:45cb597a29af6e745c378b",
        messagingSenderId: "772886464594",
        projectId: "my-project-859f5",
        storageBucket: "my-project-859f5.firebasestorage.app",
        authDomain: "my-project-859f5.firebaseapp.com",
        measurementId: "G-0YWCWRKVHW",
      ),
    );
  } catch (e, s) {
    // If Firebase fails to initialize, surface the error in a simple UI
    // so we can see the exception on device instead of a black screen.
    runApp(ErrorReportApp(exception: e, stack: s));
    return;
  }
  // Workaround for intermittent web Firestore watch errors: disable persistence
  try {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  } catch (e) {
    // ignore errors applying settings in non-web platforms
  }
  // Global error handling: show exceptions in UI instead of white screen
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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  // Run the app normally so Widgets binding and runApp share the same zone.
  runApp(const UniversityApp());
}

class ErrorReportApp extends StatelessWidget {
  final Object exception;
  final StackTrace stack;
  const ErrorReportApp(
      {super.key, required this.exception, required this.stack});

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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Poppins'),

          // Start with the new Welcome Role Selection screen
          home: const AuthGate(),
          initialRoute: null, // Let AuthGate decide

          // Define Names for modules for easy navigation
          getPages: [
            // Welcome & Auth Routes
            GetPage(name: '/welcome', page: () => const WelcomeRoleScreen()),
            GetPage(name: '/login', page: () => const LoginView()),
            GetPage(name: '/recruiter-login', page: () => const RecruiterAuthScreen()),
            
            // Main Dashboard Routes
            GetPage(
                name: '/dashboard',
                page: () =>
                    const HomeDashboard()), // Home Dashboard - main screen after login
            GetPage(name: '/admin', page: () => const AdminDashboard()),
            
            // Feature Module Routes
            GetPage(
                name: '/lost-and-found',
                page: () =>
                    const LostAndFoundLandingPage()), // Lost & Found module
            GetPage(
                name: '/timetable',
                page: () => const TimetableScreen()), // Timetable module
            GetPage(name: '/marketplace', page: () => const StudentMarketplace()),
            
            // Complaints module
            GetPage(name: '/complaints', page: () => StudentComplaintView()),
            GetPage(name: '/complaints/create', page: () => const CreateComplaintScreen()),
            GetPage(name: '/complaints/admin', page: () => AdminComplaintList()),
            
            // AI Study Planner module
            GetPage(name: '/ai-study-planner', page: () => const StudyPlannerModule()),
            
            // Placement module (student & recruiter)
            GetPage(name: '/student-placement', page: () => const StudentPlacementScreen()),
            GetPage(name: '/recruiter-dashboard', page: () => const RecruiterAdminPanel()),
          ],
        );
      },
    );
  }
}

/// AuthGate: Smart routing based on authentication state
/// - Not logged in -> Show Welcome Screen (Role Selection)
/// - Logged in but email not verified -> Show Email Verification
/// - Logged in and verified -> Show Dashboard
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // User is logged in
      return user.emailVerified
          ? const HomeDashboard() // Verified -> Dashboard
          : const VerifyEmailView(); // Not verified -> Verify email
    }
    
    // No user logged in -> Show Welcome Screen (Role Selection)
    return const WelcomeRoleScreen();
  }
}