import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shared.dart';
import 'auth.dart'; // To access current user

// ==========================================
// PHONE VALIDATION HELPER
// ==========================================

class PhoneValidator {
  /// Validates phone number format: +923115428907 or 03115428907
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^(\+92|0)[0-9]{10}$');
    return phoneRegex.hasMatch(phone.replaceAll(' ', '').replaceAll('-', ''));
  }

  /// Formats phone to international format: +923115428907
  static String formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('0')) {
      return '+92' + cleaned.substring(1);
    }
    return cleaned;
  }
}

// ==========================================
// HELPER WIDGET FOR IMAGE DISPLAY
// ==========================================

/// Displays image from either base64 string (Firestore) or network URL
class SmartImageDisplay extends StatelessWidget {
  final String imageData;
  final double width;
  final double height;
  final BoxFit fit;

  const SmartImageDisplay({
    super.key,
    required this.imageData,
    this.width = double.infinity,
    this.height = 300,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Check if it's base64 (starts with /9j for JPEG or iVBOR for PNG)
    if (imageData.startsWith('/9j/') || imageData.startsWith('iVBOR')) {
      try {
        Uint8List bytes = base64Decode(imageData);
        return Image.memory(bytes, width: width, height: height, fit: fit);
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Container(
            width: width,
            height: height,
            color: Colors.grey,
            child: const Icon(Icons.broken_image));
      }
    } else {
      // Assume it's a network URL
      return CachedNetworkImage(
        imageUrl: imageData,
        width: width,
        height: height,
        fit: fit,
        placeholder: (c, u) =>
            Container(color: Colors.grey, width: width, height: height),
        errorWidget: (c, u, e) => Container(
            width: width,
            height: height,
            color: Colors.grey,
            child: const Icon(Icons.broken_image)),
      );
    }
  }
}

// ==========================================
// MODELS & METHODS SPECIFIC TO MODULE
// ==========================================

class Post {
  final String description,
      uid,
      postId,
      username,
      postUrl,
      title,
      category,
      postType,
      location,
      phone;
  final datePublished;

  Post(
      {required this.category,
      required this.postType,
      required this.location,
      required this.description,
      required this.uid,
      required this.postId,
      required this.username,
      required this.datePublished,
      required this.postUrl,
      required this.title,
      required this.phone});

  Map<String, dynamic> toJson() => {
        'description': description,
        'uid': uid,
        'postId': postId,
        'username': username,
        'datePublished': datePublished,
        'postUrl': postUrl,
        'title': title,
        'category': category,
        'postType': postType,
        'location': location,
        'phone': phone,
      };
}

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadPost(
      String description,
      Uint8List file,
      String uid,
      String username,
      String title,
      String category,
      String location,
      String postType,
      String phone) async {
    try {
      // Convert image to base64 (stored in Firestore, no Cloud Storage needed)
      String base64Image = base64Encode(file);

      String postId = const Uuid().v1();
      Post post = Post(
        description: description,
        uid: uid,
        username: username,
        postId: postId,
        datePublished: DateTime.now(),
        postUrl: base64Image, // Store base64 directly in Firestore
        category: category,
        location: location,
        postType: postType,
        title: title,
        phone: phone,
      );

      await _firestore.collection('posts').doc(postId).set(post.toJson());
      debugPrint('Post created successfully with base64 image');
      return "Success";
    } catch (e, s) {
      debugPrint('Error uploading post: $e');
      debugPrint('Stack: $s');
      return e.toString();
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      debugPrint('Post deleted successfully');
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  Future<String> updatePost(String postId, String title, String description,
      String location, String category, String phone) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'title': title,
        'description': description,
        'location': location,
        'category': category,
        'phone': phone,
      });
      debugPrint('Post updated successfully');
      return "Success";
    } catch (e) {
      debugPrint('Error updating post: $e');
      return e.toString();
    }
  }
}

// ==========================================
// MODULE VIEWS
// ==========================================

class LostAndFoundLandingPage extends StatefulWidget {
  const LostAndFoundLandingPage({super.key});
  @override
  State<LostAndFoundLandingPage> createState() =>
      _LostAndFoundLandingPageState();
}

class _LostAndFoundLandingPageState extends State<LostAndFoundLandingPage> {
  String name = "User";

  @override
  void initState() {
    super.initState();
    AuthService().getName().then((val) {
      if (val.isNotEmpty) setState(() => name = val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lost & Found"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.to(() => const ProfileView()),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BigText(text: "Hello, $name", color: AppColors.darkGrey, size: 30),
            const SizedBox(height: 20),
            // Create Advert Card
            GestureDetector(
              onTap: () => Get.to(() => const CreatePostView()),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.lightMainColor2,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold),
                      size: 40, color: AppColors.mainColor),
                  const SizedBox(width: 20),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BigText(
                            text: "Create Advert",
                            color: AppColors.darkGrey,
                            size: 20),
                        const SmallText(
                            text: "Report lost or found items", size: 12)
                      ])
                ]),
              ),
            ),
            const SizedBox(height: 20),
            // View Posts Card
            GestureDetector(
              onTap: () => Get.to(() => const PostsListView()),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.lightYellow,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Image.asset("assets/images/items.png", height: 50),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BigText(
                              text: "Lost & Found Items",
                              color: AppColors.darkGrey,
                              size: 20),
                          SmallText(text: "Browse the list", size: 12)
                        ]),
                  )
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostsListView extends StatefulWidget {
  const PostsListView({super.key});
  @override
  State<PostsListView> createState() => _PostsListViewState();
}

class _PostsListViewState extends State<PostsListView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String selectedCategory = 'All';
  String selectedType = 'All';
  bool sortByEarliest = false; // false -> newest first, true -> earliest first

  List<String> categories() => ['All', 'Gadgets', 'Books', 'Id-Card', 'Bottle', 'Other'];
  List<String> types() => ['All', 'Found', 'Lost'];

  String _timeAgo(DateTime date) {
    final d = DateTime.now().difference(date);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final fields = [
      (data['title'] ?? '').toString(),
      (data['description'] ?? '').toString(),
      (data['location'] ?? '').toString(),
      (data['username'] ?? '').toString(),
    ];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Items'),
        actions: [
          IconButton(
            icon: Icon(sortByEarliest ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: sortByEarliest ? 'Sort: earliest first' : 'Sort: newest first',
            onPressed: () => setState(() => sortByEarliest = !sortByEarliest),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, description, location, or user',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Filters
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => selectedCategory = v ?? 'All'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedType,
                  items: types().map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => selectedType = v ?? 'All'),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('posts').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No items found'));

                  // Map docs -> filtered list
                  List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
                  List<QueryDocumentSnapshot> filtered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (selectedCategory != 'All' && (data['category'] ?? 'Other') != selectedCategory) return false;
                    if (selectedType != 'All' && (data['postType'] ?? 'Found') != selectedType) return false;
                    if (!_matchesSearch(data, _searchCtrl.text)) return false;
                    return true;
                  }).toList();

                  // Sort by datePublished
                  filtered.sort((a, b) {
                    DateTime da, db;
                    final A = a.data() as Map<String, dynamic>;
                    final B = b.data() as Map<String, dynamic>;
                    final ta = A['datePublished'];
                    final tb = B['datePublished'];
                    if (ta is Timestamp) da = ta.toDate(); else if (ta is DateTime) da = ta; else da = DateTime.tryParse(ta.toString()) ?? DateTime.now();
                    if (tb is Timestamp) db = tb.toDate(); else if (tb is DateTime) db = tb; else db = DateTime.tryParse(tb.toString()) ?? DateTime.now();
                    return sortByEarliest ? da.compareTo(db) : db.compareTo(da);
                  });

                  if (filtered.isEmpty) return const Center(child: Text('No items match filters'));

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      // Date handling
                      DateTime date;
                      final ts = data['datePublished'];
                      if (ts is Timestamp) date = ts.toDate(); else if (ts is DateTime) date = ts; else date = DateTime.tryParse(ts.toString()) ?? DateTime.now();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: ListTile(
                          leading: SizedBox(width: 60, height: 60, child: SmartImageDisplay(imageData: data['postUrl'], width: 60, height: 60, fit: BoxFit.cover)),
                          title: Text(data['title'] ?? ''),
                          subtitle: Text('${data['postType'] ?? ''} • ${data['location'] ?? ''} • ${_timeAgo(date)}'),
                          onTap: () => Get.to(() => PostDetailView(snap: doc)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});
  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  String postType = "Found";
  String category = "Gadgets";
  Uint8List? _file;
  bool isLoading = false;

  selectImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      var bytes = await file.readAsBytes();
      setState(() => _file = bytes);
    }
  }

  post() async {
    if (_file == null) {
      MySnackBar()
          .mySnackBar(header: "Error", content: "Please select an image");
      return;
    }
    if (_phone.text.isEmpty) {
      MySnackBar().mySnackBar(
          header: "Error", content: "Please enter your phone number");
      return;
    }
    if (!PhoneValidator.isValidPhone(_phone.text)) {
      MySnackBar().mySnackBar(
          header: "Error",
          content: "Phone format invalid. Use +923115428907 or 03115428907");
      return;
    }
    setState(() => isLoading = true);
    try {
      var user = AuthService().currentUser!;
      String name = await AuthService().getName(); // Fetch name dynamically
      String formattedPhone = PhoneValidator.formatPhone(_phone.text);
      String res = await FirestoreMethods().uploadPost(
          _desc.text,
          _file!,
          user.uid,
          name,
          _title.text,
          category,
          _location.text,
          postType,
          formattedPhone);
      setState(() => isLoading = false);
      if (res == "Success") {
        Get.back();
        MySnackBar().mySnackBar(
            header: "Success",
            content: "Post created",
            bgColor: Colors.green.shade100);
      } else {
        debugPrint('Post error response: $res');
        MySnackBar().mySnackBar(
            header: "Error",
            content: res.length > 100 ? res.substring(0, 100) + "..." : res,
            bgColor: Colors.red.shade100);
      }
    } catch (e, s) {
      setState(() => isLoading = false);
      debugPrint('Unexpected error in post(): $e');
      debugPrint('Stack: $s');
      MySnackBar().mySnackBar(
          header: "Error", content: e.toString(), bgColor: Colors.red.shade100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Post")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: selectImage,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: _file == null
                          ? const Icon(Icons.add_a_photo, size: 50)
                          : Image.memory(_file!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                            label: const Text("Found"),
                            selected: postType == "Found",
                            onSelected: (b) =>
                                setState(() => postType = "Found")),
                        ChoiceChip(
                            label: const Text("Lost"),
                            selected: postType == "Lost",
                            onSelected: (b) =>
                                setState(() => postType = "Lost")),
                      ]),
                  DropdownButton<String>(
                    value: category,
                    items: ['Gadgets', 'Books', 'Id-Card', 'Bottle', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => category = v!),
                  ),
                  TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: "Title")),
                  TextFormField(
                      controller: _desc,
                      decoration:
                          const InputDecoration(labelText: "Description")),
                  TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: "Location")),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                        labelText: "Your Phone Number",
                        hintText: "+923115428907 or 03115428907",
                        helperText: "Enter WhatsApp/Phone number"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  BlueButton(onPressed: post, text: "Post Ad")
                ],
              ),
            ),
    );
  }
}

class PostDetailView extends StatelessWidget {
  final dynamic snap;
  const PostDetailView({super.key, required this.snap});

  @override
  Widget build(BuildContext context) {
    var currentUser = AuthService().currentUser;
    bool isOwner = currentUser?.uid == snap['uid'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Details"),
        actions: isOwner
            ? [
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text("Edit"),
                      onTap: () => Get.to(() => EditPostView(snap: snap)),
                    ),
                    PopupMenuItem(
                      child: const Text("Delete"),
                      onTap: () => _showDeleteConfirmation(context),
                    ),
                  ],
                )
              ]
            : [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SmartImageDisplay(
                imageData: snap['postUrl'],
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BigText(
                        text: snap['title'],
                        color: Colors.black,
                        align: TextAlign.left),
                    Text("Posted by: ${snap['username']}",
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(snap['description']),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Icon(Icons.location_on),
                      Text(snap['location'])
                    ]),
                    const SizedBox(height: 20),
                    if (!isOwner)
                      BlueButton(
                          onPressed: () {
                            String phone = snap['phone'] ?? "N/A";
                            if (phone.isEmpty || phone == "N/A") {
                              Get.snackbar(
                                  "Error", "Phone number not available");
                            } else {
                              launchUrl(Uri.parse("tel:$phone"));
                            }
                          },
                          text: "Contact")
                  ]),
            )
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await FirestoreMethods().deletePost(snap['postId']);
                Get.back(); // Go back to posts list
                Get.snackbar("Success", "Post deleted",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.shade100);
              } catch (e) {
                Get.snackbar("Error", "Failed to delete post: $e",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade100);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class EditPostView extends StatefulWidget {
  final dynamic snap;
  const EditPostView({super.key, required this.snap});

  @override
  State<EditPostView> createState() => _EditPostViewState();
}

class _EditPostViewState extends State<EditPostView> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _location;
  late TextEditingController _phone;
  late String category;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.snap['title']);
    _desc = TextEditingController(text: widget.snap['description']);
    _location = TextEditingController(text: widget.snap['location']);
    _phone = TextEditingController(text: widget.snap['phone']);
    category = widget.snap['category'] ?? 'Other';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Post")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            children: [
              DropdownButton(
                value: category,
                items: ['Gadgets', 'Books', 'Id-Card', 'Bottle', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: "Title")),
              TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: "Description")),
              TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: "Location")),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                    labelText: "Your Phone Number",
                    hintText: "+923115428907 or 03115428907",
                    helperText: "Enter WhatsApp/Phone number"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator()
                  : BlueButton(onPressed: _updatePost, text: "Update Post")
            ],
          ),
        ),
      ),
    );
  }

  _updatePost() async {
    if (_title.text.isEmpty ||
        _desc.text.isEmpty ||
        _location.text.isEmpty ||
        _phone.text.isEmpty) {
      MySnackBar()
          .mySnackBar(header: "Error", content: "All fields are required");
      return;
    }
    if (!PhoneValidator.isValidPhone(_phone.text)) {
      MySnackBar().mySnackBar(
          header: "Error",
          content: "Phone format invalid. Use +923115428907 or 03115428907");
      return;
    }
    setState(() => isLoading = true);
    try {
      String formattedPhone = PhoneValidator.formatPhone(_phone.text);
      String res = await FirestoreMethods().updatePost(
        widget.snap['postId'],
        _title.text,
        _desc.text,
        _location.text,
        category,
        formattedPhone,
      );
      setState(() => isLoading = false);
      if (res == "Success") {
        Get.back();
        MySnackBar().mySnackBar(
            header: "Success",
            content: "Post updated",
            bgColor: Colors.green.shade100);
      } else {
        MySnackBar().mySnackBar(
            header: "Error", content: res, bgColor: Colors.red.shade100);
      }
    } catch (e) {
      setState(() => isLoading = false);
      MySnackBar().mySnackBar(
          header: "Error", content: e.toString(), bgColor: Colors.red.shade100);
    }
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    var user = AuthService().currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                  user.photoURL ?? "https://via.placeholder.com/150")),
          const SizedBox(height: 10),
          Text(user.email ?? "",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          BlueButton(
              width: 200,
              onPressed: () async {
                await AuthService().logOut();
                Get.offAllNamed('/login');
              },
              text: "Logout"),
          const SizedBox(height: 20),
          const Text("My Posts",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    // compute time-ago
                    DateTime date;
                    final ts = data['datePublished'];
                    if (ts is Timestamp) {
                      date = ts.toDate();
                    } else if (ts is DateTime) {
                      date = ts;
                    } else {
                      date = DateTime.tryParse(ts.toString()) ?? DateTime.now();
                    }
                    final diff = DateTime.now().difference(date);
                    String ago;
                    if (diff.inSeconds < 60) ago = '${diff.inSeconds}s ago';
                    else if (diff.inMinutes < 60) ago = '${diff.inMinutes}m ago';
                    else if (diff.inHours < 24) ago = '${diff.inHours}h ago';
                    else if (diff.inDays < 7) ago = '${diff.inDays}d ago';
                    else ago = '${date.day}/${date.month}/${date.year}';

                    return ListTile(
                      leading: SizedBox(width: 50, height: 50, child: SmartImageDisplay(imageData: data['postUrl'], width: 50, height: 50, fit: BoxFit.cover)),
                      title: Text(data['title'] ?? ''),
                      subtitle: Text('${data['postType'] ?? ''} • ${data['location'] ?? ''} • $ago'),
                      onTap: () => Get.to(() => PostDetailView(snap: doc)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            Get.to(() => EditPostView(snap: doc));
                          } else if (v == 'delete') {
                            // confirm
                            final confirmed = await Get.dialog<bool>(
                              AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text('Are you sure you want to delete this post?'),
                                actions: [
                                  TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Get.back(result: true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await FirestoreMethods().deletePost(data['postId'] ?? doc.id);
                                Get.snackbar('Success', 'Post deleted', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.shade100);
                              } catch (e) {
                                Get.snackbar('Error', 'Failed to delete: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
