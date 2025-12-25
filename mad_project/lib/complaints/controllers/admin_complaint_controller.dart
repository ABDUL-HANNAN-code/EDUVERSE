// lib/complaints/controllers/admin_complaint_controller.dart

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';

class AdminComplaintController extends GetxController {
  final ComplaintService _service = ComplaintService();

  final complaints = <ComplaintModel>[].obs;
  final isLoading = false.obs;
  final currentFilter = ComplaintStatus.pending.obs;

  final replyController = TextEditingController();
  final selectedStatus = Rx<ComplaintStatus?>(null);
  final selectedUniId = ''.obs;
  StreamSubscription<List<ComplaintModel>>? _complaintSub;

  @override
  void onInit() {
    super.onInit();
    loadComplaints();
  }

  @override
  void onClose() {
    replyController.dispose();
    _complaintSub?.cancel();
    super.onClose();
  }

  void loadComplaints() async {
    isLoading.value = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      Get.snackbar('Error', 'Not authenticated',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    String uniId = '';
    String deptId = '';

    if (selectedUniId.value.isNotEmpty) {
      uniId = selectedUniId.value;
    } else {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = doc.data() ?? {};
        uniId = data['uniId'] ?? '';
        deptId = data['departmentId'] ?? '';
      } catch (e) {
        // ignore and leave uniId empty
      }
    }

    try {
      // Cancel any existing subscription before creating a new one (prevents
      // multiple listeners and stale state after reload/login).
      await _complaintSub?.cancel();

      print(
          'AdminComplaintController: loading complaints for uid=$uid uniId="$uniId" deptId="$deptId" filter=${currentFilter.value}');

      _complaintSub = _service
          .getAdminComplaints(
              uniId: uniId, deptId: deptId, statusFilter: currentFilter.value)
          .listen((dataList) {
        print(
            'AdminComplaintController: received ${dataList.length} complaints');
        complaints.value = dataList;
        isLoading.value = false;
      }, onError: (error) {
        isLoading.value = false;
        print('AdminComplaintController: error loading complaints: $error');
        String message = 'Failed to load complaints';
        if (error is FirebaseException) {
          message = '${message}: ${error.message}';
          // If Firestore indicates an index is required, extract the URL and
          // offer to open it in the browser so the developer can create it.
          final msg = error.message ?? '';
          final urlMatch =
              RegExp(r'(https?:\/\/\S*indexes?\S*)').firstMatch(msg);
          if (urlMatch != null) {
            final url = urlMatch.group(0)!;
            print('AdminComplaintController: index URL detected: $url');
            Get.defaultDialog(
              title: 'Index Required',
              middleText:
                  'A Firestore composite index is required to run this query. Open the console to create it?',
              textConfirm: 'Open Index',
              onConfirm: () async {
                Get.back();
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    Get.snackbar('Error', 'Cannot open browser for index link',
                        snackPosition: SnackPosition.BOTTOM);
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Failed to open index link: $e',
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
              textCancel: 'Cancel',
            );
          }
        } else if (error != null) {
          message = '${message}: $error';
        }
        Get.snackbar('Error', message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100,
            colorText: Colors.red.shade900);

        // Attempt a lightweight fallback fetch (recent complaints) so the
        // admin sees something while an index is created or building.
        _service.getRecentComplaintsFallback(limit: 20).then((fallbackList) {
          if (fallbackList.isNotEmpty) {
            print(
                'AdminComplaintController: fallback returned ${fallbackList.length} complaints');
            complaints.value = fallbackList;
            Get.snackbar(
                'Notice', 'Showing recent complaints while index builds',
                snackPosition: SnackPosition.BOTTOM);
          } else {
            print('AdminComplaintController: fallback returned no complaints');
          }
        });
      });
    } catch (e) {
      isLoading.value = false;
      print('AdminComplaintController: exception in loadComplaints: $e');
      Get.snackbar('Error', 'Failed to load complaints: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    }
  }

  /// Set the selected university for admin view (useful for super-admins)
  void setSelectedUniversity(String uniId) {
    selectedUniId.value = uniId;
    loadComplaints();
  }

  void changeFilter(ComplaintStatus status) {
    currentFilter.value = status;
    loadComplaints();
  }

  Future<void> updateComplaint(String complaintId) async {
    if (selectedStatus.value == null) {
      Get.snackbar(
        'Required',
        'Please select a status',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    try {
      isLoading.value = true;

      if (replyController.text.trim().isNotEmpty) {
        await _service.updateComplaintWithReply(
          complaintId: complaintId,
          newStatus: selectedStatus.value!,
          reply: replyController.text.trim(),
        );
      } else {
        await _service.updateComplaintStatus(
          complaintId: complaintId,
          newStatus: selectedStatus.value!,
        );
      }

      replyController.clear();
      selectedStatus.value = null;
      isLoading.value = false;

      Get.back();
      Get.snackbar(
        'Success',
        'Complaint updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to update complaint: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  void openActionSheet(ComplaintModel complaint) {
    selectedStatus.value = complaint.status;
    replyController.text = complaint.adminReply ?? '';

    Get.bottomSheet(
      _buildActionBottomSheet(complaint),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildActionBottomSheet(ComplaintModel complaint) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(Get.context!).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Update Complaint',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => Wrap(
                  spacing: 8,
                  children: ComplaintStatus.values.map((status) {
                    final isSelected = selectedStatus.value == status;
                    return ChoiceChip(
                      label: Text(status.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          selectedStatus.value = status;
                        }
                      },
                      selectedColor: const Color(0xFF667EEA),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                )),
            const SizedBox(height: 20),
            const Text(
              'Admin Reply (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replyController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your response to the student...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF667EEA), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading.value
                        ? null
                        : () => updateComplaint(complaint.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update Complaint',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
