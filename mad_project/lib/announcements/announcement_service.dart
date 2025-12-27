import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'announcement_model.dart';

class AnnouncementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch announcements filtered by University ID
  Stream<List<Announcement>> getAnnouncementsStream(String uniId) {
    return _db
        .collection('announcements')
        .where('uniId', isEqualTo: uniId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            debugPrint('Announcements snapshot for uniId=$uniId count=${snapshot.docs.length}');
          } catch (_) {}
          return snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();
        });
  }

  /// Create new announcement
  Future<void> createAnnouncement({
    required String title,
    required String content,
    String? imageBase64,
    required String uniId,
    required String authorName,
  }) async {
    await _db.collection('announcements').add({
      'title': title,
      'content': content,
      'imageBase64': imageBase64,
      'uniId': uniId,
      'postedBy': authorName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Delete announcement
  Future<void> deleteAnnouncement(String docId) async {
    await _db.collection('announcements').doc(docId).delete();
  }

  /// Update announcement
  Future<void> updateAnnouncement({
    required String docId,
    required String title,
    required String content,
    String? imageBase64,
  }) async {
    await _db.collection('announcements').doc(docId).update({
      'title': title,
      'content': content,
      'imageBase64': imageBase64,
    });
  }
}