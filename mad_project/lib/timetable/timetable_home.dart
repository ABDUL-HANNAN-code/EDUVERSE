import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../homepage/admin_dashboard.dart';
import '../shared.dart';
import 'timetable_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _service = TimetableService();

  // User Context
  String? uniId, deptId, sectionId, shift;
  String? semester;
  bool isSuperAdmin = false;
  bool isAdmin = false;
  List<Map<String, dynamic>> universities = [];
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> sections = [];
  bool isLoading = true;
  String selectedDay = 'Monday';

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  // TASK 1: Enhanced User Context Loading
  Future<void> _loadUserContext() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            final role = data?['role']?.toString();
            isSuperAdmin = (role == 'super_admin');
            isAdmin = (role == 'admin' || role == 'super_admin');

            // Load profile data
            uniId = data?['uniId']?.toString();
            deptId = data?['departmentId']?.toString();
            sectionId = data?['sectionId']?.toString();
            shift = data?['shift']?.toString();
            semester = data?['semester']?.toString();

            // TASK 1: If Super Admin without profile uniId, check adminScope
            final adminScope = data?['adminScope'] as Map<String, dynamic>?;
            if (uniId == null &&
                adminScope != null &&
                adminScope['uniId'] != null) {
              uniId = adminScope['uniId']?.toString();
            }
          });
        }

        // TASK 1: If super admin, fetch universities for selection
        if (isSuperAdmin) {
          await _fetchUniversities();
        }
      }
    } catch (e) {
      debugPrint('Error loading user context: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchUniversities() async {
    try {
      final list = await _service.getAllUniversities();
      if (mounted) {
        setState(() {
          universities = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching universities: $e');
    }
  }

  Future<void> _fetchDepartments(String universityId) async {
    try {
      final list = await _service.getDepartments(universityId);
      if (mounted) {
        setState(() {
          departments = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
    }
  }

  Future<void> _fetchSections(String universityId, String departmentId) async {
    try {
      final list = await _service.getSections(universityId, departmentId);
      if (mounted) {
        setState(() {
          sections = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // TASK 1: Handle Super Admin without University
    if (uniId == null) {
      if (isSuperAdmin) {
        return _buildSuperAdminUniversitySelector();
      }

      // Regular user without university
      return Scaffold(
        appBar: AppBar(title: const Text('My Timetable')),
        body: const Center(
          child: Text("Error: No University Linked to your account"),
        ),
      );
    }

    // TASK 1: Super Admin with selected university but no dept/section
    if (isSuperAdmin && (deptId == null || sectionId == null)) {
      return _buildSuperAdminDepartmentSelector();
    }

    // Normal timetable view
    return _buildTimetableView();
  }

  // TASK 1: University Selector for Super Admin
  Widget _buildSuperAdminUniversitySelector() {
    if (universities.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Timetable'),
          backgroundColor: Colors.purple,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No universities found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please add a university from the Admin Dashboard.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: _fetchUniversities,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Open Admin Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select University'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are signed in as Super Admin.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select a university to view its timetable.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: (() {
                final uniqueUnis = {
                  for (var u in universities) (u['id'] as String): u
                }.values.toList();
                return uniqueUnis.any((u) => u['id'] == uniId) ? uniId : null;
              })(),
              items: (() {
                final uniqueUnis = {
                  for (var u in universities) (u['id'] as String): u
                }.values.toList();
                return uniqueUnis
                    .map((u) => DropdownMenuItem(
                        value: u['id'] as String,
                        child: Text(u['name'] ?? u['id']!)))
                    .toList();
              })(),
              onChanged: (val) async {
                setState(() {
                  uniId = val;
                  deptId = null;
                  sectionId = null;
                });
                if (val != null) {
                  await _fetchDepartments(val);
                }
              },
              decoration: const InputDecoration(
                labelText: 'University',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (isAdmin)
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Go to Admin Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // TASK 1: Department/Section Selector for Super Admin
  Widget _buildSuperAdminDepartmentSelector() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Department & Section'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            uniId = null;
            deptId = null;
            sectionId = null;
          }),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'University: ${universities.firstWhere((u) => u['id'] == uniId, orElse: () => {
                    'name': uniId
                  })['name']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a department and section to view the timetable:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: (() {
                final uniqueDepts = {
                  for (var d in departments) (d['id'] as String): d
                }.values.toList();
                return uniqueDepts.any((d) => d['id'] == deptId)
                    ? deptId
                    : null;
              })(),
              items: (() {
                final uniqueDepts = {
                  for (var d in departments) (d['id'] as String): d
                }.values.toList();
                return uniqueDepts
                    .map((d) => DropdownMenuItem(
                        value: d['id'] as String,
                        child: Text(d['name'] ?? d['id']!)))
                    .toList();
              })(),
              onChanged: (val) async {
                setState(() {
                  deptId = val;
                  sectionId = null;
                });
                if (val != null && uniId != null) {
                  await _fetchSections(uniId!, val);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Department',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (deptId != null)
              DropdownButtonFormField<String>(
                value: (() {
                  final uniqueSecs = {
                    for (var s in sections) (s['id'] as String): s
                  }.values.toList();
                  return uniqueSecs.any((s) => s['id'] == sectionId)
                      ? sectionId
                      : null;
                })(),
                items: (() {
                  final uniqueSecs = {
                    for (var s in sections) (s['id'] as String): s
                  }.values.toList();
                  return uniqueSecs
                      .map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] ?? s['id']!)))
                      .toList();
                })(),
                onChanged: (val) => setState(() => sectionId = val),
                decoration: const InputDecoration(
                  labelText: 'Section',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            if (deptId != null)
              DropdownButtonFormField<String>(
                value: shift ?? 'morning',
                items: const [
                  DropdownMenuItem(value: 'morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'evening', child: Text('Evening')),
                ],
                onChanged: (val) => setState(() => shift = val),
                decoration: const InputDecoration(
                  labelText: 'Shift',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 24),
            if (isAdmin)
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Go to Admin Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Normal Timetable View
  Widget _buildTimetableView() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Timetable'),
            Text(
              '${deptId?.toUpperCase()} - Sec $sectionId ($shift)',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: isSuperAdmin ? Colors.purple : AppColors.mainColor,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Day Selector
          _buildDaySelector(),

          // Timetable Content
          Expanded(child: _buildTimetableContent()),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (c, i) {
          final day = days[i];
          final isSelected = day == selectedDay;
          return GestureDetector(
            onTap: () => setState(() => selectedDay = day),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border(
                        bottom: BorderSide(
                          color: isSuperAdmin
                              ? Colors.purple
                              : AppColors.mainColor,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Text(
                day,
                style: TextStyle(
                  color: isSelected
                      ? (isSuperAdmin ? Colors.purple : AppColors.mainColor)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimetableContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getAdminTimetableStream(
        uniId: uniId!,
        deptId: deptId,
        sectionId: sectionId,
        shift: shift,
        semester: semester,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Filter for selected day
        final docs =
            snapshot.data!.docs.where((d) => d['day'] == selectedDay).toList();

        // Sort by time
        docs.sort(
            (a, b) => (a['start'] as String).compareTo(b['start'] as String));

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildClassCard(data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.weekend, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "No classes on $selectedDay",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: Color(data['colorValue'] ?? 0xFF3498DB),
            width: 6,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                data['start'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                data['end'],
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['subject'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      data['location'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data['teacher'],
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
