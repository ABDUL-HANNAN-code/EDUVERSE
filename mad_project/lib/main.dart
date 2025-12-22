import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_marketplace.dart';

import 'shared.dart'; // Import Shared components
import 'auth.dart'; // Import Auth logic
import 'lost_and_found.dart'; // Import the Module
import 'timetable/index.dart'; // Import Timetable Module
import 'homepage/index.dart'; // Import Home Dashboard Module
import 'homepage/admin_dashboard.dart';

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
          title: 'Uni App',
          theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Poppins'),

          // Decide where to start
          home: const AuthGate(),
          initialRoute: null, // Let AuthGate decide

          // Define Names for modules for easy navigation
          getPages: [
            GetPage(name: '/login', page: () => const LoginView()),
            GetPage(
                name: '/dashboard',
                page: () =>
                    const HomeDashboard()), // Home Dashboard - main screen after login
            GetPage(
                name: '/lost-and-found',
                page: () =>
                    const LostAndFoundLandingPage()), // Lost & Found module
            GetPage(
                name: '/timetable',
                page: () => const TimetableScreen()), // Timetable module
            GetPage(name: '/admin', page: () => const AdminDashboard()),

            GetPage(
                name: '/marketplace', page: () => const StudentMarketplace()),
          ],
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.emailVerified
          ? const HomeDashboard()
          : const VerifyEmailView();
    }
    return const LoginView();
  }
}
