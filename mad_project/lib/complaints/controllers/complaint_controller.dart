// lib/complaints/controllers/complaint_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';

class ComplaintController extends GetxController {
  final ComplaintService _service = ComplaintService();

  final complaints = <ComplaintModel>[].obs;
  final isLoading = false.obs;
  final statistics = <String, int>{}.obs;

  // Form controllers
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final selectedCategory = Rx<ComplaintCategory?>(null);
  final selectedUrgency = ComplaintUrgency.low.obs;
  final isAnonymous = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadStudentComplaints();
    loadStatistics();
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  void loadStudentComplaints() {
    isLoading.value = true;
    _service.getStudentComplaints().listen(
      (data) {
        complaints.value = data;
        isLoading.value = false;
      },
      onError: (error) {
        isLoading.value = false;
        Get.snackbar(
          'Error',
          'Failed to load complaints',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
        );
      },
    );
  }

  Future<void> loadStatistics() async {
    final stats = await _service.getStudentStatistics();
    statistics.value = stats;
  }

  Future<void> submitComplaint({
    required String uniId,
    required String deptId,
  }) async {
    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        'Required',
        'Please enter a title',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      Get.snackbar(
        'Required',
        'Please enter a description',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    if (selectedCategory.value == null) {
      Get.snackbar(
        'Required',
        'Please select a category',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    try {
      isLoading.value = true;

      await _service.submitComplaint(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        category: selectedCategory.value!,
        urgency: selectedUrgency.value,
        isAnonymous: isAnonymous.value,
        uniId: uniId,
        deptId: deptId,
      );

      // Clear form
      titleController.clear();
      descriptionController.clear();
      selectedCategory.value = null;
      selectedUrgency.value = ComplaintUrgency.low;
      isAnonymous.value = false;

      isLoading.value = false;

      Get.back();
      Get.snackbar(
        'Success',
        'Complaint submitted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );

      await loadStatistics();
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to submit complaint: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  void selectCategory(ComplaintCategory category) {
    selectedCategory.value = category;
  }

  void selectUrgency(ComplaintUrgency urgency) {
    selectedUrgency.value = urgency;
  }

  void toggleAnonymous(bool value) {
    isAnonymous.value = value;
  }
}