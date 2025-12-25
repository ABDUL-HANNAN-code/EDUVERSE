// File: lib/modules/placement/screens/recruiter_admin_panel.dart
// Complete Recruiter Admin Panel with Firebase Authentication & Firestore

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODELS ====================

class RecruiterUser {
  final String uid;
  final String email;
  final String companyName;
  final String role; // 'recruiter'
  final String? photoUrl;

  RecruiterUser({
    required this.uid,
    required this.email,
    required this.companyName,
    required this.role,
    this.photoUrl,
  });

  factory RecruiterUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RecruiterUser(
      uid: doc.id,
      email: data['email'] ?? '',
      companyName: data['companyName'] ?? '',
      role: data['role'] ?? 'recruiter',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'companyName': companyName,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class JobPosting {
  final String? id;
  final String title;
  final String company;
  final String salary;
  final String description;
  final String requirements;
  final String targetUniversity;
  final bool isRemote;
  final String location;
  final String recruiterId;
  final String recruiterEmail;
  final int applicantsCount;
  final DateTime? createdAt;
  final bool isActive;

  JobPosting({
    this.id,
    required this.title,
    required this.company,
    required this.salary,
    required this.description,
    required this.requirements,
    required this.targetUniversity,
    required this.isRemote,
    required this.location,
    required this.recruiterId,
    required this.recruiterEmail,
    this.applicantsCount = 0,
    this.createdAt,
    this.isActive = true,
  });

  factory JobPosting.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return JobPosting(
      id: doc.id,
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      salary: data['salary'] ?? '',
      description: data['description'] ?? '',
      requirements: data['requirements'] ?? '',
      targetUniversity: data['targetUniversity'] ?? 'All Universities',
      isRemote: data['isRemote'] ?? false,
      location: data['location'] ?? '',
      recruiterId: data['recruiterId'] ?? '',
      recruiterEmail: data['recruiterEmail'] ?? '',
      applicantsCount: data['applicantsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'company': company,
      'salary': salary,
      'description': description,
      'requirements': requirements,
      'targetUniversity': targetUniversity,
      'isRemote': isRemote,
      'location': location,
      'recruiterId': recruiterId,
      'recruiterEmail': recruiterEmail,
      'applicantsCount': applicantsCount,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}

// ==================== AUTHENTICATION SERVICE ====================

class RecruiterAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign In
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is a recruiter
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'User not found. Please contact admin.'
        };
      }

      Map userData = userDoc.data() as Map<String, dynamic>;
      if (userData['role'] != 'recruiter') {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Access denied. This portal is for recruiters only.'
        };
      }

      return {'success': true, 'user': result.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  // Sign Up (Register new recruiter)
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String companyName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'companyName': companyName,
        'role': 'recruiter',
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': false, // Needs admin approval
      });

      return {'success': true, 'user': result.user};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get Recruiter Data
  Future<RecruiterUser?> getRecruiterData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return RecruiterUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting recruiter data: $e');
      return null;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

// ==================== FIRESTORE SERVICE ====================

class RecruiterFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Post a Job
  Future<Map<String, dynamic>> postJob(JobPosting job) async {
    try {
      await _firestore.collection('jobs').add(job.toMap());
      return {'success': true, 'message': 'Job posted successfully!'};
    } catch (e) {
      return {'success': false, 'message': 'Error posting job: ${e.toString()}'};
    }
  }

  // Get Recruiter's Jobs (Real-time)
  Stream<List<JobPosting>> getRecruiterJobs(String recruiterId) {
    return _firestore
        .collection('jobs')
        .where('recruiterId', isEqualTo: recruiterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => JobPosting.fromFirestore(doc))
          .toList();
    });
  }

  // Update Job
  Future<Map<String, dynamic>> updateJob(String jobId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update(data);
      return {'success': true, 'message': 'Job updated successfully!'};
    } catch (e) {
      return {'success': false, 'message': 'Error updating job: ${e.toString()}'};
    }
  }

  // Delete Job
  Future<Map<String, dynamic>> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
      return {'success': true, 'message': 'Job deleted successfully!'};
    } catch (e) {
      return {'success': false, 'message': 'Error deleting job: ${e.toString()}'};
    }
  }

  // Get Total Applicants Count
  Future<int> getTotalApplicants(String recruiterId) async {
    try {
      QuerySnapshot applicationsSnapshot = await _firestore
          .collection('applications')
          .where('recruiterId', isEqualTo: recruiterId)
          .get();
      return applicationsSnapshot.size;
    } catch (e) {
      print('Error getting applicants count: $e');
      return 0;
    }
  }

  // Get Applications for a specific job
  Stream<QuerySnapshot> getJobApplications(String jobId) {
    return _firestore
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }
}

// ==================== LOGIN SCREEN ====================

class RecruiterLoginScreen extends StatefulWidget {
  const RecruiterLoginScreen({Key? key}) : super(key: key);

  @override
  State<RecruiterLoginScreen> createState() => _RecruiterLoginScreenState();
}

class _RecruiterLoginScreenState extends State<RecruiterLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = RecruiterAuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUp = false;
  final _companyNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> result;

    if (_isSignUp) {
      result = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        companyName: _companyNameController.text.trim(),
      );
    } else {
      result = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (_isSignUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Awaiting admin approval.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RecruiterAdminPanel(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E0D48), Color(0xFF5E2686)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.business_center,
                      size: 60,
                      color: Color(0xFF5E2686),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    _isSignUp ? 'Recruiter Registration' : 'Recruiter Portal',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Create your recruiter account'
                        : 'Sign in to manage job postings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Company Name (Sign Up only)
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _companyNameController,
                              decoration: InputDecoration(
                                labelText: 'Company Name',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F7),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter company name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F7),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F7),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5E2686),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'Create Account' : 'Sign In',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Toggle Sign Up/Sign In
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                              });
                            },
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign In'
                                  : 'New recruiter? Create Account',
                              style: const TextStyle(
                                color: Color(0xFF5E2686),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== MAIN ADMIN PANEL ====================

class RecruiterAdminPanel extends StatefulWidget {
  const RecruiterAdminPanel({Key? key}) : super(key: key);

  @override
  State<RecruiterAdminPanel> createState() => _RecruiterAdminPanelState();
}

class _RecruiterAdminPanelState extends State<RecruiterAdminPanel> {
  final _authService = RecruiterAuthService();
  final _firestoreService = RecruiterFirestoreService();
  RecruiterUser? _recruiterData;
  int _totalApplicants = 0;

  @override
  void initState() {
    super.initState();
    _loadRecruiterData();
  }

  Future<void> _loadRecruiterData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _authService.getRecruiterData(user.uid);
      final applicants = await _firestoreService.getTotalApplicants(user.uid);
      setState(() {
        _recruiterData = data;
        _totalApplicants = applicants;
      });
    }
  }

  void _showPostJobSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostJobBottomSheet(
        recruiterId: _authService.currentUser!.uid,
        recruiterEmail: _authService.currentUser!.email!,
        companyName: _recruiterData?.companyName ?? '',
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const RecruiterLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const RecruiterLoginScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2E0D48), Color(0xFF5E2686)],
                ),
              ),
              child: FlexibleSpaceBar(
                title: const Text(
                  'Recruiter Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_recruiterData != null) ...[
                          Text(
                            _recruiterData!.companyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Sign Out',
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  StreamBuilder<List<JobPosting>>(
                    stream: _firestoreService.getRecruiterJobs(user.uid),
                    builder: (context, snapshot) {
                      int activeJobs = snapshot.data?.length ?? 0;

                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Active Jobs',
                              '$activeJobs',
                              Icons.work_outline,
                              const Color(0xFF5E2686),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Applicants',
                              '$_totalApplicants',
                              Icons.people_outline,
                              const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Posted Jobs Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Posted Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showPostJobSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Post Job'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5E2686),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Jobs List
                  StreamBuilder<List<JobPosting>>(
                    stream: _firestoreService.getRecruiterJobs(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final jobs = snapshot.data ?? [];

                      if (jobs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.work_off_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No jobs posted yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _showPostJobSheet,
                                  child: const Text('Post Your First Job'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          return RecruiterJobCard(
                            job: jobs[index],
                            onEdit: () => _showEditJobSheet(jobs[index]),
                            onDelete: () => _deleteJob(jobs[index].id!),
                            onViewApplications: () =>
                                _showApplications(jobs[index]),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostJobSheet,
        backgroundColor: const Color(0xFF5E2686),
        icon: const Icon(Icons.add),
        label: const Text('Post Job'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditJobSheet(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostJobBottomSheet(
        recruiterId: _authService.currentUser!.uid,
        recruiterEmail: _authService.currentUser!.email!,
        companyName: _recruiterData?.companyName ?? '',
        existingJob: job,
      ),
    );
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _firestoreService.deleteJob(jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showApplications(JobPosting job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobApplicationsScreen(job: job),
      ),
    );
  }
}

// ==================== JOB CARD WIDGET ====================

class RecruiterJobCard extends StatelessWidget {
  final JobPosting job;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewApplications;

  const RecruiterJobCard({
    Key? key,
    required this.job,
    required this.onEdit,
    required this.onDelete,
    required this.onViewApplications,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5E2686).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF5E2686),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.work_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 18,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Posted for: ${job.targetUniversity}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: onViewApplications,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${job.applicantsCount} Applicants',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.salary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: job.isRemote
                      ? Colors.blue[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.isRemote ? 'Remote' : 'On-site',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: job.isRemote ? Colors.blue[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== POST JOB BOTTOM SHEET ====================

class PostJobBottomSheet extends StatefulWidget {
  final String recruiterId;
  final String recruiterEmail;
  final String companyName;
  final JobPosting? existingJob;

  const PostJobBottomSheet({
    Key? key,
    required this.recruiterId,
    required this.recruiterEmail,
    required this.companyName,
    this.existingJob,
  }) : super(key: key);

  @override
  State<PostJobBottomSheet> createState() => _PostJobBottomSheetState();
}

class _PostJobBottomSheetState extends State<PostJobBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = RecruiterFirestoreService();

  late TextEditingController _titleController;
  late TextEditingController _salaryController;
  late TextEditingController _descriptionController;
  late TextEditingController _requirementsController;
  late TextEditingController _locationController;

  String _selectedUniversity = 'All Universities';
  bool _isRemote = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingJob?.title ?? '');
    _salaryController = TextEditingController(text: widget.existingJob?.salary ?? '');
    _descriptionController = TextEditingController(text: widget.existingJob?.description ?? '');
    _requirementsController = TextEditingController(text: widget.existingJob?.requirements ?? '');
    _locationController = TextEditingController(text: widget.existingJob?.location ?? 'Lahore/Islamabad');
    
    if (widget.existingJob != null) {
      _selectedUniversity = widget.existingJob!.targetUniversity;
      _isRemote = widget.existingJob!.isRemote;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _salaryController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final job = JobPosting(
      id: widget.existingJob?.id,
      title: _titleController.text.trim(),
      company: widget.companyName,
      salary: _salaryController.text.trim(),
      description: _descriptionController.text.trim(),
      requirements: _requirementsController.text.trim(),
      targetUniversity: _selectedUniversity,
      isRemote: _isRemote,
      location: _locationController.text.trim(),
      recruiterId: widget.recruiterId,
      recruiterEmail: widget.recruiterEmail,
      applicantsCount: widget.existingJob?.applicantsCount ?? 0,
    );

    Map<String, dynamic> result;

    if (widget.existingJob != null) {
      // Update existing job
      result = await _firestoreService.updateJob(
        widget.existingJob!.id!,
        job.toMap(),
      );
    } else {
      // Create new job
      result = await _firestoreService.postJob(job);
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingJob != null ? 'Edit Job' : 'Post New Job',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Job Title',
                      hint: 'e.g., Flutter Developer',
                      icon: Icons.work_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _salaryController,
                      label: 'Salary',
                      hint: 'e.g., \$15M or 150,000 PKR/month',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Job Description',
                      hint: 'Describe the role and responsibilities...',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _requirementsController,
                      label: 'Requirements',
                      hint: 'List the required skills and qualifications...',
                      icon: Icons.checklist,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'e.g., Lahore/Islamabad',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),

                    // University Dropdown
                    const Text(
                      'Who can see this?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUniversity,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: [
                            'All Universities',
                            'Air University',
                            'NUST',
                            'Bahria University',
                            'FAST University',
                            'COMSATS',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value == 'All Universities'
                                    ? '$value (Global)'
                                    : value,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedUniversity = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remote Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Remote Work',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Switch(
                            value: _isRemote,
                            onChanged: (value) {
                              setState(() {
                                _isRemote = value;
                              });
                            },
                            activeColor: const Color(0xFF5E2686),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Submit Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E2686),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.existingJob != null ? 'Update Job' : 'Post Job',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }
}

// ==================== JOB APPLICATIONS SCREEN ====================

class JobApplicationsScreen extends StatelessWidget {
  final JobPosting job;
  final _firestoreService = RecruiterFirestoreService();

  JobApplicationsScreen({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        backgroundColor: const Color(0xFF5E2686),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getJobApplications(job.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final applications = snapshot.data?.docs ?? [];

          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No applications yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final app = applications[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF5E2686),
                    child: Text(
                      (app['studentName'] ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(app['studentName'] ?? 'Student'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app['studentEmail'] ?? ''),
                      Text(app['university'] ?? ''),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      app['status'] ?? 'pending',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.orange[100],
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