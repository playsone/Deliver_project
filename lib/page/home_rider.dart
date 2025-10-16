// home_rider.dart

import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/package_model.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// --- IMPORT MODELS AND PAGES ---
// !สำคัญ: ตรวจสอบว่า Path ของไฟล์ Model และ Page ถูกต้อง
import '../models/order_model.dart';
import '../models/rider_model.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/package_delivery_page.dart';

// ------------------------------------------------------------------
// Controller (ส่วนจัดการ Logic ทั้งหมดของหน้า Home)
// ------------------------------------------------------------------
class RiderHomeController extends GetxController {
  final String uid;
  final int role;
  RiderHomeController({required this.uid, required this.role});

  // --- State ---
  final Rx<RiderModel?> rider = Rx(null);
  final db = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();

    // 1. ตรวจสอบงานที่ค้างอยู่ก่อนเป็นอันดับแรก
    _checkAndNavigateToActiveOrder();

    // 2. จากนั้นค่อยเริ่มฟังข้อมูลของ Rider ตามปกติ
    rider.bindStream(
      db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? RiderModel.fromFirestore(doc) : null),
    );
  }

  // ฟังก์ชันใหม่สำหรับตรวจสอบและนำทางไปยังงานที่ Rider รับไว้
  Future<void> _checkAndNavigateToActiveOrder() async {
    try {
      // ค้นหางานที่ riderId ตรงกับ uid ของเรา และสถานะยังไม่เสร็จสิ้น
      final querySnapshot = await db
          .collection('orders') // **แก้ไข:** ใช้ collection 'orders'
          .where('riderId', isEqualTo: uid)
          .where('currentStatus',
              whereIn: ['accepted', 'picked_up', 'in_transit'])
          .limit(1) // เอามาแค่งานเดียว
          .get();

      // ถ้าเจองานที่ค้างอยู่
      if (querySnapshot.docs.isNotEmpty) {
        final activeOrderDoc = querySnapshot.docs.first;
        final orderModel = OrderModel.fromFirestore(activeOrderDoc);

        log('Rider has an active order: ${orderModel.id}. Navigating...');

        // แปลง OrderModel เป็น Package เพื่อส่งต่อ
        final package = Package(
          id: orderModel.id,
          title: orderModel.orderDetails,
          location: orderModel.pickupAddress.detail,
          destination: orderModel.deliveryAddress.detail,
          imageUrl: orderModel.orderPicture,
        );

        // ใช้ Get.offAll เพื่อไปหน้า delivery และลบหน้า home ทิ้งจาก stack
        Get.offAll(() => PackageDeliveryPage(
              package: package,
              uid: uid,
              role: role,
            ));
      } else {
        log('Rider has no active orders. Showing pending list.');
      }
    } catch (e) {
      log('Error checking for active order: $e');
    }
  }

  // Stream สำหรับดึงรายการงานที่ยังว่างอยู่ (pending)
  Stream<List<OrderModel>> getPendingOrdersStream() {
    return db
        .collection('orders') // **แก้ไข:** ใช้ collection 'orders'
        .where('currentStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  // ฟังก์ชันสำหรับกด "รับงาน"
  Future<void> acceptOrder(OrderModel order) async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final orderRef = db
          .collection('orders')
          .doc(order.id); // **แก้ไข:** ใช้ collection 'orders'

      await orderRef.update({
        'riderId': uid,
        'currentStatus': 'accepted',
        'statusHistory': FieldValue.arrayUnion([
          {'status': 'accepted', 'timestamp': Timestamp.now()}
        ]),
      });

      Get.back(); // ปิด Loading

      final package = Package(
        id: order.id,
        title: order.orderDetails,
        location: order.pickupAddress.detail,
        destination: order.deliveryAddress.detail,
        imageUrl: order.orderPicture,
      );

      // เมื่อรับงานสำเร็จ ให้ไปที่หน้า Delivery ทันที
      Get.to(() => PackageDeliveryPage(
            package: package,
            uid: uid,
            role: role,
          ));
    } catch (e) {
      Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถรับงานนี้ได้: $e');
    }
  }
}

// ------------------------------------------------------------------
// Rider Home Screen (ส่วน UI)
// ------------------------------------------------------------------
class RiderHomeScreen extends StatelessWidget {
  final String uid;
  final int role;
  const RiderHomeScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    // สร้างและลงทะเบียน Controller
    final controller = Get.put(RiderHomeController(uid: uid, role: role));

    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, controller),
            _buildContentHeader(),
            Expanded(
              child: _buildPackageList(controller),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // Header ที่ใช้ Obx เพื่อแสดงข้อมูลจาก Controller แบบ Realtime
  Widget _buildHeader(BuildContext context, RiderHomeController controller) {
    return Obx(() {
      final riderData = controller.rider.value;
      String riderName = riderData?.fullname ?? 'ไรเดอร์';
      String profileImageUrl =
          riderData?.profileUrl ?? 'https://picsum.photos/200';

      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFC70808),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(50),
            bottomRight: Radius.circular(50),
          ),
        ),
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'สวัสดีคุณ $riderName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () => _showProfileOptions(context, uid, role),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(profileImageUrl),
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: const Text('รายการงานที่รอการจัดส่ง',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // รายการงานที่ดึงข้อมูลจาก Stream ใน Controller
  Widget _buildPackageList(RiderHomeController controller) {
    return StreamBuilder<List<OrderModel>>(
      stream: controller.getPendingOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('ไม่มีงานให้รับในขณะนี้',
                  style: TextStyle(fontSize: 16, color: Colors.grey)));
        }

        final orders = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildPackageCard(context, order, controller);
          },
        );
      },
    );
  }

  // Card แสดงรายละเอียดของงานแต่ละชิ้น
  Widget _buildPackageCard(
      BuildContext context, OrderModel order, RiderHomeController controller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: order.orderPicture != null
                    ? DecorationImage(
                        image: NetworkImage(order.orderPicture!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: order.orderPicture == null
                  ? const Icon(Icons.inventory_2_outlined,
                      size: 40, color: Colors.black54)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderDetails,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFC70808)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  _buildPackageDetailRow(
                      Icons.store, 'ต้นทาง: ${order.pickupAddress.detail}'),
                  _buildPackageDetailRow(Icons.location_on,
                      'ปลายทาง: ${order.deliveryAddress.detail}'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => controller.acceptOrder(order),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF38B000),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('รับงาน',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 5)
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'ประวัติการส่ง'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }

  void _showProfileOptions(BuildContext context, String uid, int role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Divider(
                    indent: 150,
                    endIndent: 150,
                    thickness: 4,
                    color: Colors.grey),
              ),
              _buildOptionButton(
                  context, 'แก้ไขข้อมูลส่วนตัว', Icons.person_outline, () {
                Get.to(() => EditProfilePage(uid: uid, role: role));
              }),
              _buildOptionButton(context, 'เปลี่ยนรหัสผ่าน', Icons.lock_outline,
                  () {
                Navigator.pop(context);
              }),
              _buildOptionButton(context, 'ออกจากระบบ', Icons.logout, () {
                Get.offAll(() => const SpeedDerApp());
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFFC70808)),
            const SizedBox(width: 15),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
