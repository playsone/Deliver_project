// package_delivery_page.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// Enum เพื่อจัดการสถานะการจัดส่ง
enum DeliveryStatus {
  accepted,
  pickedUp,
  inTransit,
  delivered,
}

class PackageDeliveryPage extends StatefulWidget {
  final Package package;
  final String uid;
  final int role;
  const PackageDeliveryPage(
      {super.key,
      required this.package,
      required this.uid,
      required this.role});

  @override
  State<PackageDeliveryPage> createState() => _PackageDeliveryPageState();
}

class _PackageDeliveryPageState extends State<PackageDeliveryPage> {
  String? _currentRiderId;

  @override
  void initState() {
    super.initState();
    _currentRiderId = widget.uid;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ฟังก์ชันกลาง: สำหรับถ่ายรูป, อัปโหลด, และอัปเดตสถานะ
  Future<void> _captureAndUploadStatusImage({
    required String nextStatus,
    required String imageUrlField,
    bool isFinal = false,
  }) async {
    final picker = ImagePicker();
    try {
      final pickedFile =
          await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
      if (pickedFile == null) return;

      Get.dialog(const Center(child: CircularProgressIndicator()),
          barrierDismissible: false);

      final cloudinary =
          CloudinaryPublic('dnutmbomv', 'delivery888', cache: false);
      final response =
          await cloudinary.uploadFile(CloudinaryFile.fromFile(pickedFile.path));
      final imageUrl = response.secureUrl;

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.package.id);

      // คำสั่งนี้จะสร้างฟิลด์ใหม่ให้เองถ้ายังไม่มี
      await orderRef.update({
        'currentStatus': nextStatus,
        imageUrlField: imageUrl,
        'statusHistory': FieldValue.arrayUnion([
          {'status': nextStatus, 'timestamp': Timestamp.now()}
        ]),
      });

      Get.back();
      Get.snackbar('สำเร็จ', 'อัปเดตสถานะเรียบร้อยแล้ว');

      if (isFinal) {
        await Future.delayed(const Duration(seconds: 1));
        Get.offAll(() => RiderHomeScreen(uid: widget.uid, role: widget.role));
        Get.snackbar('เสร็จสิ้น', 'ดำเนินการจัดส่งเสร็จสมบูรณ์!');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถอัปเดตสถานะได้: $e');
    }
  }

  DeliveryStatus _mapStatusToEnum(String status) {
    switch (status) {
      case 'accepted':
        return DeliveryStatus.accepted;
      case 'picked_up':
        return DeliveryStatus.pickedUp;
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.accepted;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFC70808);

    return WillPopScope(
      onWillPop: () async {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.package.id)
            .get();
        if (doc.exists && doc.data()?['currentStatus'] != 'delivered') {
          Get.dialog(
            AlertDialog(
              title: const Text('ยังไม่สามารถย้อนกลับได้'),
              content: const Text('กรุณาดำเนินการจัดส่งสินค้าให้เสร็จสิ้นก่อน'),
              actions: [
                TextButton(
                    onPressed: () => Get.back(), child: const Text('ตกลง'))
              ],
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('ขั้นตอนการจัดส่ง'),
          backgroundColor: primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.package.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final currentDbStatus = data['currentStatus'] ?? 'accepted';
            final deliveryStatusEnum = _mapStatusToEnum(currentDbStatus);

            return Column(
              children: [
                _buildStatusTracker(primaryColor, deliveryStatusEnum),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        _buildActionSection(deliveryStatusEnum),
                        const SizedBox(height: 20),
                        _buildEvidenceImage(data),
                        const SizedBox(height: 20),
                        _buildDeliveryInfoSection(data),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusTracker(Color primaryColor, DeliveryStatus currentStatus) {
    final List<Map<String, dynamic>> steps = [
      {'icon': Icons.check_circle_outline, 'label': 'รับงาน'},
      {'icon': Icons.inventory_2, 'label': 'รับของ'},
      {'icon': Icons.local_shipping, 'label': 'จัดส่ง'},
      {'icon': Icons.task_alt, 'label': 'สำเร็จ'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          bool isActive = currentStatus.index >= index;
          return Column(
            children: [
              Icon(
                steps[index]['icon'] as IconData,
                color: isActive ? Colors.white : Colors.white54,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                steps[index]['label'],
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 12),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActionSection(DeliveryStatus currentStatus) {
    if (currentStatus == DeliveryStatus.delivered) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('จัดส่งสินค้านี้เรียบร้อยแล้ว',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    String buttonText;
    VoidCallback onPressed;
    IconData? icon;
    switch (currentStatus) {
      case DeliveryStatus.accepted:
        buttonText = 'ถ่ายรูปยืนยันการรับของ';
        icon = Icons.camera_alt;
        onPressed = () => _captureAndUploadStatusImage(
              nextStatus: 'picked_up',
              imageUrlField: 'pickedUpImageUrl',
            );
        break;
      case DeliveryStatus.pickedUp:
        buttonText = 'ถ่ายรูปเพื่อเริ่มนำส่ง';
        icon = Icons.local_shipping;
        onPressed = () => _captureAndUploadStatusImage(
              nextStatus: 'in_transit',
              imageUrlField: 'inTransitImageUrl', // บันทึกลงฟิลด์ใหม่
            );
        break;
      case DeliveryStatus.inTransit:
        buttonText = 'ถ่ายรูปยืนยันการส่งสำเร็จ';
        icon = Icons.photo_camera;
        onPressed = () => _captureAndUploadStatusImage(
              nextStatus: 'delivered',
              imageUrlField: 'deliveredImageUrl',
              isFinal: true,
            );
        break;
      default:
        buttonText = '...';
        icon = Icons.error;
        onPressed = () {};
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildEvidenceImage(Map<String, dynamic> orderData) {
    final pickedUpUrl = orderData['pickedUpImageUrl'] as String?;
    final inTransitUrl = orderData['inTransitImageUrl'] as String?;
    final deliveredUrl = orderData['deliveredImageUrl'] as String?;

    if (pickedUpUrl == null && inTransitUrl == null && deliveredUrl == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pickedUpUrl != null)
          _buildImageCard('รูปภาพตอนรับของ', pickedUpUrl),
        if (inTransitUrl != null)
          _buildImageCard('รูปภาพตอนเริ่มนำส่ง', inTransitUrl),
        if (deliveredUrl != null)
          _buildImageCard('รูปภาพตอนจัดส่งสำเร็จ', deliveredUrl),
      ],
    );
  }

  Widget _buildImageCard(String title, String imageUrl) {
    return _buildInfoBox(title: title, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 50),
                    SizedBox(height: 8),
                    Text('ไม่สามารถโหลดรูปภาพได้'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildDeliveryInfoSection(Map<String, dynamic> orderData) {
    final pickupAddress =
        orderData['pickupAddress'] as Map<String, dynamic>? ?? {};
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final customerId = orderData['customerId'] as String?;

    return _buildInfoBox(
      title: 'ข้อมูลการจัดส่ง',
      children: [
        _buildInfoRow(
          icon: Icons.storefront,
          label: 'รับจาก',
          value: pickupAddress['detail'] ?? 'N/A',
        ),
        if (customerId != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(customerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(child: LinearProgressIndicator()),
                );
              }
              final senderData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.person,
                    label: 'ผู้ส่ง',
                    value: senderData['fullname'] ?? 'ไม่มีข้อมูล',
                  ),
                  _buildInfoRow(
                    icon: Icons.phone,
                    label: 'เบอร์ติดต่อ (ผู้ส่ง)',
                    value: senderData['phone'] ?? 'ไม่มีข้อมูล',
                  ),
                ],
              );
            },
          )
        else
          _buildInfoRow(
              icon: Icons.person, label: 'ผู้ส่ง', value: 'ไม่มีข้อมูล'),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.location_on,
          label: 'ส่งที่',
          value: deliveryAddress['detail'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.person_pin,
          label: 'ผู้รับ',
          value: deliveryAddress['receiverName'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.phone_android,
          label: 'เบอร์ติดต่อ (ผู้รับ)',
          value: deliveryAddress['receiverPhone'] ?? 'N/A',
        ),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'รายละเอียดสินค้า',
          value: orderData['orderDetails'] ?? 'N/A',
        ),
      ],
    );
  }

  Widget _buildInfoBox(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC70808)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}