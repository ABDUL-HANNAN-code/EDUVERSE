import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'lost_and_found.dart';

class LostAndFoundAdminList extends StatefulWidget {
  final String? adminViewUniId;
  const LostAndFoundAdminList({super.key, this.adminViewUniId});

  @override
  State<LostAndFoundAdminList> createState() => _LostAndFoundAdminListState();
}

class _LostAndFoundAdminListState extends State<LostAndFoundAdminList> {
  String? _resolvedUniId;

  @override
  void initState() {
    super.initState();
    _resolvedUniId = widget.adminViewUniId;
  }

  @override
  Widget build(BuildContext context) {
    final stream = (_resolvedUniId == null || _resolvedUniId!.isEmpty)
        ? FirebaseFirestore.instance.collection('posts').orderBy('datePublished', descending: true).snapshots()
        : FirebaseFirestore.instance.collection('posts').where('uniId', isEqualTo: _resolvedUniId).orderBy('datePublished', descending: true).snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No posts', style: TextStyle(color: Colors.grey[600])));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = data['title'] ?? 'No title';
              final uid = data['uid'] ?? '';
              final uniId = data['uniId'] ?? '';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('Uni: ${uniId.toString()} • By: ${uid.toString()}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final confirmed = await Get.dialog<bool>(AlertDialog(
                          title: const Text('Delete Post'),
                          content: const Text('Are you sure you want to delete this post?'),
                          actions: [
                            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Delete')),
                          ],
                        ));
                        if (confirmed == true) {
                          try {
                            await FirestoreMethods().deletePost(doc.id);
                            Get.snackbar('Success', 'Post deleted', snackPosition: SnackPosition.BOTTOM);
                          } catch (e) {
                            Get.snackbar('Error', 'Failed to delete: $e', snackPosition: SnackPosition.BOTTOM);
                          }
                        }
                      } else if (v == 'view') {
                        Get.to(() => PostDetailView(snap: doc));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
