// package_pickup_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:delivery_project/page/order_status_page.dart'; // อาจต้อง Import หน้ารายละเอียดสถานะหากมี

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

// ------------------------------------------------------------------
// Model (ปรับปรุง: เพิ่ม orderDetails และ deliveredImageUrl)
// ------------------------------------------------------------------
class PackageModel {
  final String id;
  final String source;
  final String destination;
  final String currentStatus;
  final String customerId;
  final String? riderId;
  final String orderDetails;
  final String? deliveredImageUrl;

  PackageModel({
    required this.id,
    required this.source,
    required this.destination,
    required this.currentStatus,
    required this.customerId,
    this.riderId,
    required this.orderDetails,
    this.deliveredImageUrl,
  });

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String sourceDetail = data['pickupAddress']?['detail'] ?? 'ไม่ระบุต้นทาง';
    String destinationDetail =
        data['deliveryAddress']?['detail'] ?? 'ไม่ระบุปลายทาง';

    // ดึง Delivered Image URL
    String? deliveredImgUrl;
    if (data['currentStatus'] == 'delivered' ||
        data['currentStatus'] == 'completed') {
      deliveredImgUrl = data['deliveredImageUrl'];

      // หรือค้นหาจาก statusHistory (กรณีที่ใช้ delivered เป็นสถานะสุดท้ายที่มีรูป)
      if (deliveredImgUrl == null && data['statusHistory'] is List) {
        final deliveredEntry = (data['statusHistory'] as List).firstWhereOrNull(
            (h) =>
                h['status'] == 'delivered' &&
                h['imgOfStatus']?.isNotEmpty == true);
        deliveredImgUrl = deliveredEntry?['imgOfStatus'];
      }
    }

    return PackageModel(
      id: doc.id,
      source: 'จาก: $sourceDetail',
      destination: 'ไปที่: $destinationDetail',
      currentStatus: data['currentStatus'] ?? 'unknown',
      customerId: data['customerId'] ?? '',
      riderId: data['riderId'],
      orderDetails: data['orderDetails'] ?? 'ไม่ระบุรายละเอียดสินค้า',
      deliveredImageUrl: deliveredImgUrl,
    );
  }
}

// ------------------------------------------------------------------
// Controller (สำหรับการจัดการข้อมูลและการค้นหา)
// ------------------------------------------------------------------
class PackagePickupController extends GetxController {
  final String uid;
  final RxString userPhone = ''.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchText = ''.obs; // NEW: ตัวแปรเก็บคำค้นหาที่ใช้จริง

  PackagePickupController(this.uid);

  @override
  void onInit() {
    _fetchUserPhone();
    super.onInit();
  }

  // ดึงเบอร์โทรศัพท์ของผู้ใช้ปัจจุบัน
  Future<void> _fetchUserPhone() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        userPhone.value = doc.data()?['phone'] ?? '';
      }
    } catch (e) {
      print('Error fetching user phone: $e');
    }
  }

  // 1. ฟังก์ชัน Stream สำหรับดึงพัสดุที่ถูกส่งมายังผู้ใช้คนนี้ (ผ่านเบอร์โทร)
  Stream<QuerySnapshot> getRecipientPackagesStream() {
    if (userPhone.value.isEmpty) {
      return Stream.empty();
    }
    // ค้นหาพัสดุทั้งหมดที่มี receiverPhone ตรงกับเบอร์โทรศัพท์ของผู้ใช้
    final baseQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryAddress.receiverPhone', isEqualTo: userPhone.value)
        .snapshots();
  }

  // 2. ฟังก์ชันสำหรับดึงชื่อผู้ใช้ (ผู้ส่ง/ไรเดอร์) จาก UID (เหมือนเดิม)
  Future<String> getUserName(String userId, String defaultName) async {
    if (userId.isEmpty) return defaultName;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data()?['fullname'] ?? defaultName;
      }
      return defaultName;
    } catch (e) {
      return defaultName;
    }
  }

  // 3. ฟังก์ชันสำหรับอัพเดทสถานะเป็น 'completed'
  Future<void> confirmPackageReception(String orderId) async {
    Get.dialog(
        const Center(child: CircularProgressIndicator(color: _primaryColor)),
        barrierDismissible: false);
    try {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);

      await orderRef.update({
        'currentStatus': 'completed',
        'statusHistory': FieldValue.arrayUnion([
          {
            'imgOfStatus': 'received by recipient',
            'status': 'completed',
            'timestamp': Timestamp.now()
          }
        ]),
      });

      Get.back();
      Get.snackbar('สำเร็จ', 'ยืนยันการรับพัสดุ $orderId เรียบร้อยแล้ว',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถยืนยันการรับได้: $e',
          backgroundColor: _primaryColor, colorText: Colors.white);
    }
  }
}

// ------------------------------------------------------------------
// Page (UI)
// ------------------------------------------------------------------
class PackagePickupPage extends StatelessWidget {
  final String uid;
  final int role;
  // uid ในหน้านี้จะถูกใช้เป็น uid ของผู้รับ (เพื่อค้นหาเบอร์โทร)
  const PackagePickupPage({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PackagePickupController(uid));

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSearchBar(controller), // Pass controller
                  const SizedBox(height: 20),
                  // ใช้ Obx เพื่อรอให้ userPhone ถูกโหลดก่อน และรอคำค้นหา
                  Obx(() {
                    if (controller.userPhone.value.isEmpty) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: CircularProgressIndicator(color: _primaryColor),
                      ));
                    }
                    // เรียกใช้ StreamBuilder ภายใน Obx
                    return _buildPackagesList(controller);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // 4. Widget แสดงรายการพัสดุด้วย StreamBuilder (เพิ่มการกรอง Client-side)
  Widget _buildPackagesList(PackagePickupController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getRecipientPackagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: Text(
                '📦 ไม่มีรายการพัสดุที่กำลังถูกส่งถึงคุณในขณะนี้',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final packages = snapshot.data!.docs
            .map((doc) => PackageModel.fromFirestore(doc))
            .toList();

        return Column(
          children: filteredPackages.map((package) {
            String statusText;
            Color statusColor;
            bool showConfirmButton = false;

            switch (package.currentStatus) {
              case 'pending':
                statusText = 'รอไรเดอร์รับงาน';
                statusColor = Colors.blueGrey;
                break;
              case 'assigned':
                statusText = 'ไรเดอร์รับงานแล้ว';
                statusColor = Colors.orange;
                break;
              case 'picked_up':
                statusText = 'รับพัสดุแล้ว';
                statusColor = Colors.amber.shade800;
                break;
              case 'in_transit':
                statusText = 'กำลังนำส่ง';
                statusColor = Colors.amber.shade800;
                break;
              case 'delivered':
                statusText = 'จัดส่งสำเร็จ';
                statusColor = Colors.green;
                showConfirmButton = true; // แสดงปุ่มให้ผู้รับยืนยัน
                break;
              case 'completed':
                statusText =
                    'ได้รับสินค้าแล้ว ✔️'; // สถานะสุดท้ายที่ผู้รับต้องการเห็น
                statusColor = Colors.teal;
                break;
              default:
                statusText = 'สถานะไม่ทราบ';
                statusColor = Colors.grey;
            }

            return FutureBuilder<Map<String, String>>(
              future:
                  _fetchNames(controller, package.customerId, package.riderId),
              builder: (context, nameSnapshot) {
                String senderName =
                    nameSnapshot.data?['sender'] ?? 'กำลังโหลด...';
                String riderName =
                    nameSnapshot.data?['rider'] ?? 'ยังไม่มีไรเดอร์';

                return _buildPackageItem(
                  package,
                  statusText,
                  statusColor,
                  showConfirmButton,
                  senderName,
                  riderName,
                  controller.confirmPackageReception,
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  // ดึงชื่อผู้ส่งและไรเดอร์พร้อมกัน
  Future<Map<String, String>> _fetchNames(PackagePickupController controller,
      String customerId, String? riderId) async {
    final senderName = await controller.getUserName(customerId, 'ผู้ส่ง');
    final riderName = riderId != null
        ? await controller.getUserName(riderId, 'ไรเดอร์')
        : 'ยังไม่มีไรเดอร์';
    return {'sender': senderName, 'rider': riderName};
  }

  // 5. Widget แสดงรายการพัสดุ (ปรับปรุงให้แสดงชื่อผู้ส่ง/ไรเดอร์ + รูปหลักฐาน)
  Widget _buildPackageItem(
      PackageModel package,
      String statusText,
      Color statusColor,
      bool showConfirmButton,
      String senderName,
      String riderName,
      Function(String) onConfirm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          // สามารถนำไปหน้า OrderStatusPage ได้
          Get.snackbar(
              'รายละเอียด', 'เปิดหน้าเพื่อดูรายละเอียดพัสดุ ${package.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------ แถวหลัก (ปลายทาง/สถานะ) ------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'จัดส่งถึง: ${package.destination}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(Icons.person_outline, 'ผู้ส่ง: $senderName'),
              _buildDetailRow(
                  Icons.two_wheeler_outlined, 'ไรเดอร์: $riderName'),
              _buildDetailRow(Icons.pin_drop, package.source),
              _buildDetailRow(Icons.qr_code, 'รหัสพัสดุ: ${package.id}'),
              const SizedBox(height: 10),
              // ------------------ ปุ่มยืนยัน (ถ้ามี) ------------------
              if (showConfirmButton)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => onConfirm(package.id),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('ยืนยันการรับ',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ส่วน Header (ปรับข้อความให้สื่อถึง "ผู้รับ")
  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150.0,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        centerTitle: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'พัสดุถึงคุณ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        background: ClipPath(
          clipper: HeaderClipper(),
          child: Container(
            color: _primaryColor,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20, top: 50),
            child: const Text(
              'รายการพัสดุรอรับ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
      ),
    );
  }

  /// สร้างแถบค้นหา
  Widget _buildSearchBar(PackagePickupController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller.searchController,
        decoration: InputDecoration(
          hintText: 'ค้นหาด้วยชื่อสินค้า หรือ รหัสพัสดุ',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _primaryColor),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, offset: Offset(0, -2), blurRadius: 5),
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
            icon: Icon(Icons.history),
            label: 'ประวัติการส่งสินค้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          // โค้ดสำหรับจัดการ Navigation
        },
      ),
    );
  }
}

// Custom Clipper สำหรับ Header
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double h = size.height;
    double w = size.width;
    Path path = Path();

    path.lineTo(0, h * 0.85);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.45, h * 0.85);
    path.quadraticBezierTo(w * 0.65, h * 0.75, w, h * 0.8);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
