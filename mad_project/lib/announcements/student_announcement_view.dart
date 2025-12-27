import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'announcement_service.dart';
import 'announcement_model.dart';
import 'announcement_widgets.dart';

class StudentAnnouncementFeed extends StatelessWidget {
  const StudentAnnouncementFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please login"));

    // 1. Get User's Uni ID
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
        
        final uniId = userSnap.data?.get('uniId') as String?;
        if (uniId == null) return const Center(child: Text("No University Assigned"));

        // 2. Stream Announcements
        return Scaffold(
          backgroundColor: AppTheme.kBackgroundColor,
          appBar: AppBar(
            title: const Text("Announcements", style: TextStyle(color: AppTheme.kDarkTextColor, fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.kWhiteColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppTheme.kDarkTextColor),
          ),
          body: StreamBuilder<List<Announcement>>(
            stream: AnnouncementService().getAnnouncementsStream(uniId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final err = snapshot.error;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Failed to load announcements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(err.toString(), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        const Text('Check debug console for details.'),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No announcements yet", style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final a = announcements[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      child: AnnouncementCard(
                        announcement: a,
                        onTap: () => _showDetail(context, a),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Announcement a) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.imageBase64 != null && a.imageBase64!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.memory(base64Decode(a.imageBase64!), height: 200, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Posted by: ${a.authorId}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const Divider(height: 32),
                    Text(a.content, style: const TextStyle(fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}