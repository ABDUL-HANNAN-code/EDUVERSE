import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_marketplace.dart';
import 'homepage/profile_screen.dart';

// Announcements module
import 'announcements/student_announcement_view.dart';
import 'notifications.dart';

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

  // Register FCM token and listen for token refresh (if user signed in)
  try {
    FirebaseMessaging.instance.getToken().then((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await NotificationService().registerFcmToken(userId: user.uid, token: token);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await NotificationService().registerFcmToken(userId: user.uid, token: token);
      }
    });
  } catch (e) {
    debugPrint('FCM init error: $e');
  }

    // Initialize local notifications and FCM handlers (skip local notifications on web)
    try {
      if (!kIsWeb) {
        await _initLocalNotifications();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Foreground message -> show local notification (mobile only)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          try {
            final notif = message.notification;
            final title = notif?.title ?? '';
            final body = notif?.body ?? '';

            const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
              'eduverse_high',
              'Eduverse High Priority',
              channelDescription: 'High priority notifications for Eduverse',
              importance: Importance.high,
              priority: Priority.high,
            );
            const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

            await flutterLocalNotificationsPlugin.show(
              message.hashCode,
              title,
              body,
              platformDetails,
              payload: message.data['notificationId']?.toString() ?? '',
            );
          } catch (e) {
            debugPrint('onMessage show local notification error: $e');
          }
        });
      }

      // Request permission (iOS) and attempt to ensure notification permission on Android
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('FCM permission status: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('FCM requestPermission error: $e');
      }

      // When the app is opened from a terminated state via a notification
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
        if (message != null) {
          final nid = message.data['notificationId'];
          // navigate to notification page
          try {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            Get.toNamed('/notifications', arguments: {'userId': uid});
          } catch (_) {}
        }
      });

      // When the app is opened from background via a notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final nid = message.data['notificationId'];
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          Get.toNamed('/notifications', arguments: {'userId': uid});
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('FCM handlers init error: $e');
    }

  // Foreground message handler: show simple SnackBar
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    try {
      final notif = message.notification;
      final title = notif?.title ?? '';
      final body = notif?.body ?? '';
      // Use navigatorKey or current context via WidgetsBinding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = Navigator.of(Get.context!);
        ScaffoldMessenger.of(navigator.context).showSnackBar(
          SnackBar(content: Text('$title\n$body')),
        );
      });
    } catch (e) {
      debugPrint('onMessage handler error: $e');
    }
  });

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
    // Return a simple Scaffold instead of a nested MaterialApp to avoid
    // creating another Navigator (which can cause GlobalKey conflicts).
    return Scaffold(
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
    );
  };

  runApp(const UniversityApp());
}

// Background handler must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  // You may want to write the background notification to Firestore or process data
  debugPrint('FCM background message received: ${message.messageId}');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // NotificationResponse.payload contains the string payload (notificationId or routing data)
      final payload = response.payload;
      debugPrint('Local notification tapped, payload: $payload');
      try {
        final ctx = Get.context;
        if (ctx != null && payload != null && payload.isNotEmpty) {
          Get.toNamed('/notifications');
        }
      } catch (_) {}
    },
  );

  // Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'eduverse_high',
    'Eduverse High Priority',
    importance: Importance.high,
    description: 'High priority notifications for Eduverse',
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
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

            GetPage(name: '/profile', page: () => const ProfileScreen()),

            // --- ADDED ANNOUNCEMENTS ROUTES HERE ---
            GetPage(name: '/announcements', page: () => const StudentAnnouncementFeed()),
            // alias route (used by dashboard tile)
            GetPage(name: '/student_announcements_view', page: () => const StudentAnnouncementFeed()),
            // Notifications
            GetPage(
              name: '/notifications',
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return NotificationPage(
                  userId: args?['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
                  universityId: args?['universityId'] ?? '',
                );
              },
            ), // navigator will supply params when used
            GetPage(
              name: '/notification_settings',
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return NotificationSettingsPage(userId: args?['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '');
              },
            ),
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
            // Keep super_admin on AdminDashboard; route regular university admins
            // to the main HomeDashboard by default.
            if (role == 'super_admin') return const AdminDashboard();
            if (role == 'admin') return user.emailVerified ? const HomeDashboard() : const VerifyEmailView();

            return user.emailVerified ? const HomeDashboard() : const VerifyEmailView();
        }
      );
    }
    
    return const LoginView();
  }
}