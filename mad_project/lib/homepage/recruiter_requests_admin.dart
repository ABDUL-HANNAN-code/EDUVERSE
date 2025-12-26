import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecruiterRequestsAdmin extends StatefulWidget {
  final String? adminUniId; // if null, show all (super admin)
  const RecruiterRequestsAdmin({Key? key, this.adminUniId}) : super(key: key);

  @override
  State<RecruiterRequestsAdmin> createState() => _RecruiterRequestsAdminState();
}

class _RecruiterRequestsAdminState extends State<RecruiterRequestsAdmin> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _requestsStream() {
    if (widget.adminUniId == null) {
      return _db
          .collection('job_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return _db
        .collection('job_requests')
        .where('status', isEqualTo: 'pending')
        .where('pendingFor', arrayContains: widget.adminUniId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _approve(String reqId) async {
    final uid = widget.adminUniId;
    if (uid == null) return;

    final ref = _db.collection('job_requests').doc(reqId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;

    // mark approval and remove from pendingFor
    await ref.update({
      'approvals.${uid}': true,
      'pendingFor': FieldValue.arrayRemove([uid])
    });

    // re-fetch to see if pendingFor now empty
    final after = await ref.get();
    final afterData = after.data() as Map<String, dynamic>;
    final pending = List.from(afterData['pendingFor'] ?? []);
    if (pending.isEmpty) {
      // finalize: move to jobs collection
      final job = afterData['job'] as Map<String, dynamic>;
      final jobRef = await _db.collection('jobs').add({
        ...job,
        'recruiterId': afterData['recruiterId'],
        'recruiterEmail': afterData['recruiterEmail'],
        'companyName': afterData['companyName'],
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
      });
      await ref.update({'status': 'approved', 'approvedJobId': jobRef.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recruiter Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No pending requests'));
          return ListView(
            children: snap.data!.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final job = data['job'] as Map<String, dynamic>? ?? {};
              final pendingFor = List.from(data['pendingFor'] ?? []);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(job['title'] ?? 'Untitled'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company: ${data['companyName'] ?? ''}'),
                      Text('Target: ${data['targetUniversity'] ?? 'All'}'),
                      Text('Pending for: ${pendingFor.length}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: widget.adminUniId == null
                      ? const SizedBox.shrink()
                      : ElevatedButton(
                          onPressed: () => _approve(d.id),
                          child: const Text('Approve'),
                        ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
