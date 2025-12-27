import 'package:flutter/material.dart';
import 'dart:math' as math;
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
  bool _showGridLayout = false;

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
          IconButton(
            icon: Icon(_showGridLayout ? Icons.view_list : Icons.grid_on),
            tooltip: 'Toggle timetable layout',
            onPressed: () => setState(() => _showGridLayout = !_showGridLayout),
          ),
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
          // Day Selector (hidden in grid layout to avoid duplicate day headers)
          if (!_showGridLayout) _buildDaySelector(),

          // Timetable Content (list or read-only grid)
          Expanded(child: _showGridLayout ? _buildReadOnlyGridView() : _buildTimetableContent()),
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
                _formatTime12(data['start'] ?? ''),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTime12(data['end'] ?? ''),
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

  // Read-only grid view similar to admin layout but non-editable
  Widget _buildReadOnlyGridView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getAdminTimetableStream(
        uniId: uniId!,
        deptId: deptId,
        sectionId: sectionId,
        shift: shift,
        semester: semester,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;
        // build map by cell
        final timeSlots = _getTimeSlots(shift ?? 'morning');
        final Map<String, List<QueryDocumentSnapshot>> classesByCell = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final day = data['day'] as String? ?? '';
          final startTime = data['start'] as String? ?? '';
          final key = '$day-$startTime';
          classesByCell.putIfAbsent(key, () => []).add(doc);
        }

        // Use LayoutBuilder to compute available width and avoid RenderFlex overflow
        const headerHeight = 56.0;
        final cellHeight = 80.0;

        return LayoutBuilder(builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          var timeColumnWidth = 72.0;
          // ensure time column leaves reasonable room
          if (screenWidth < 360) timeColumnWidth = 56.0;

          final available = (screenWidth - timeColumnWidth).clamp(0.0, double.infinity);
          final cellWidth = (available / days.length);
          // For horizontal layout (days in sidebar, times on top), compute sizes
          // cellWidth will now represent width per time slot, and rowHeight per day
          final screenHeight = MediaQuery.of(context).size.height - 160; // approximate available height
          final rowHeight = math.max(56.0, (screenHeight - headerHeight) / days.length);
          final timeSlotCount = timeSlots.length;
          final slotWidth = math.max(120.0, (available / math.max(1, timeSlotCount)));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: timeColumnWidth + slotWidth * timeSlotCount,
                height: headerHeight + rowHeight * days.length,
                child: Stack(
                  children: [
                    _buildGridSkeletonHorizontal(timeSlots, slotWidth, rowHeight, headerHeight, timeColumnWidth),
                    ..._buildClassOverlaysGroupedReadOnlyHorizontal(classesByCell, timeSlots, slotWidth, rowHeight, headerHeight, timeColumnWidth),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildGridSkeletonHorizontal(
    List<Map<String, String>> timeSlots,
    double slotWidth,
    double rowHeight,
    double headerHeight,
    double dayColumnWidth,
  ) {
    return Column(
      children: [
        // Top header row: empty corner + time headers
        Row(
          children: [
            Container(
              width: dayColumnWidth,
              height: headerHeight,
              decoration: BoxDecoration(color: AppColors.mainColor, border: Border.all(color: Colors.white, width: 1)),
              child: const Center(child: Text('Days', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            ...timeSlots.map((slot) => Container(
                  width: slotWidth,
                  height: headerHeight,
                  decoration: BoxDecoration(color: AppColors.mainColor, border: Border.all(color: Colors.white, width: 1)),
                  child: Center(child: Text('${_formatTime12(slot['start'] ?? '')}\n${_formatTime12(slot['end'] ?? '')}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                )),
          ],
        ),
        // Rows per day
        ...days.map((day) {
          return Row(
            children: [
              Container(
                width: dayColumnWidth,
                height: rowHeight,
                decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300, width: 1)),
                child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
              ...timeSlots.map((_) => Container(width: slotWidth, height: rowHeight, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 1)), child: const SizedBox.shrink())),
            ],
          );
        }),
      ],
    );
  }

  List<Widget> _buildClassOverlaysGroupedReadOnlyHorizontal(
    Map<String, List<QueryDocumentSnapshot>> classesByCell,
    List<Map<String, String>> timeSlots,
    double slotWidth,
    double rowHeight,
    double headerHeight,
    double dayColumnWidth,
  ) {
    const slotDuration = 80;
    final overlays = <Widget>[];

    classesByCell.forEach((cellKey, cellDocs) {
      if (cellDocs.isEmpty) return;
      final firstData = cellDocs.first.data() as Map<String, dynamic>;
      final day = firstData['day'] as String? ?? '';
      final dayIndex = days.indexOf(day);
      if (dayIndex == -1) return;

      final startTime = firstData['start'] as String? ?? '';
      final startMin = _timeToMinutes(startTime);
      final firstSlotStart = _timeToMinutes(timeSlots.first['start']!);
      final minutesFromFirstSlot = startMin - firstSlotStart;

      final cellTop = headerHeight + (dayIndex * rowHeight);
      final cellLeft = dayColumnWidth + (minutesFromFirstSlot / slotDuration) * slotWidth;

      final classCount = cellDocs.length;
      final classWidth = math.max((slotWidth - 8) / classCount, 100.0);

      for (var i = 0; i < cellDocs.length; i++) {
        final doc = cellDocs[i];
        final data = doc.data() as Map<String, dynamic>;
        final endTime = data['end'] as String? ?? '';
        final endMin = _timeToMinutes(endTime);
        final duration = endMin - startMin;
        final classWidthPx = classWidth;
        final classHeight = math.max((duration / slotDuration) * rowHeight, 48.0);

        overlays.add(Positioned(
          top: cellTop + 4,
          left: cellLeft + 4 + (i * classWidthPx),
          width: classWidthPx - 4,
          height: classHeight - 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Color(data['colorValue'] ?? 0xFF3498DB), borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['subject'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${_formatTime12(data['start'] ?? '')}', style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(data['teacher'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ));
      }
    });

    return overlays;
  }

  Widget _buildGridSkeleton(
    List<Map<String, String>> timeSlots,
    double cellWidth,
    double cellHeight,
    double headerHeight,
    double timeColumnWidth,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: timeColumnWidth,
              height: headerHeight,
              decoration: BoxDecoration(
                color: AppColors.mainColor,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Center(
                child: Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            ...days.map((day) => Container(
                  width: cellWidth,
                  height: headerHeight,
                  decoration: BoxDecoration(color: AppColors.mainColor, border: Border.all(color: Colors.white, width: 1)),
                  child: Center(child: Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                )),
          ],
        ),
        ...timeSlots.map((slot) {
          return Row(
            children: [
              Container(
                width: timeColumnWidth,
                height: cellHeight,
                decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300, width: 1)),
                child: Center(child: Text('${_formatTime12(slot['start'] ?? '')}\n${_formatTime12(slot['end'] ?? '')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ),
              ...days.map((day) => Container(width: cellWidth, height: cellHeight, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 1)), child: const SizedBox.shrink())),
            ],
          );
        }),
      ],
    );
  }

  List<Widget> _buildClassOverlaysGroupedReadOnly(
    Map<String, List<QueryDocumentSnapshot>> classesByCell,
    List<Map<String, String>> timeSlots,
    double cellWidth,
    double cellHeight,
    double headerHeight,
    double timeColumnWidth,
  ) {
    const slotDuration = 80;
    final overlays = <Widget>[];

    classesByCell.forEach((cellKey, cellDocs) {
      if (cellDocs.isEmpty) return;
      final firstData = cellDocs.first.data() as Map<String, dynamic>;
      final day = firstData['day'] as String? ?? '';
      final dayIndex = days.indexOf(day);
      if (dayIndex == -1) return;

      final startTime = firstData['start'] as String? ?? '';
      final startMin = _timeToMinutes(startTime);
      final firstSlotStart = _timeToMinutes(timeSlots.first['start']!);
      final minutesFromFirstSlot = startMin - firstSlotStart;

      final cellTop = headerHeight + (minutesFromFirstSlot / slotDuration) * cellHeight;
      final cellLeft = timeColumnWidth + (dayIndex * cellWidth);

      final classCount = cellDocs.length;
      final classWidth = math.max((cellWidth - 8) / classCount, 64.0);

      for (var i = 0; i < cellDocs.length; i++) {
        final doc = cellDocs[i];
        final data = doc.data() as Map<String, dynamic>;
        final endTime = data['end'] as String? ?? '';
        final endMin = _timeToMinutes(endTime);
        final duration = endMin - startMin;
        final classHeight = math.max((duration / slotDuration) * cellHeight, 52.0);

        overlays.add(Positioned(
          top: cellTop,
          left: cellLeft + 4 + (i * classWidth),
          width: classWidth - 4,
          height: classHeight - 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Color(data['colorValue'] ?? 0xFF3498DB), borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['subject'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${_formatTime12(data['start'] ?? '')} - ${_formatTime12(data['end'] ?? '')}', style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(data['teacher'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(data['sectionId'] ?? data['location'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ));
      }
    });

    return overlays;
  }

  // Time helpers (copy of admin formatting utilities)
  List<Map<String, String>> _getTimeSlots(String shift) {
    if (shift == 'morning') {
      return [
        {'start': '08:00', 'end': '09:20'},
        {'start': '09:20', 'end': '10:40'},
        {'start': '10:40', 'end': '12:00'},
        {'start': '12:00', 'end': '13:20'},
        {'start': '13:20', 'end': '14:40'},
      ];
    } else {
      return [
        {'start': '14:40', 'end': '16:00'},
        {'start': '16:00', 'end': '17:20'},
        {'start': '17:20', 'end': '18:40'},
        {'start': '18:40', 'end': '20:00'},
        {'start': '20:00', 'end': '21:20'},
      ];
    }
  }

  int _timeToMinutes(String time) {
    if (!time.contains(':')) return 0;
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _formatTime12(String t24) {
    try {
      final parts = t24.split(':');
      var h = int.parse(parts[0]);
      final m = parts.length > 1 ? parts[1] : '00';
      final suffix = h < 12 ? 'AM' : 'PM';
      final displayH = (h % 12 == 0) ? 12 : (h % 12);
      return '$displayH:$m $suffix';
    } catch (_) {
      return t24;
    }
  }
}
