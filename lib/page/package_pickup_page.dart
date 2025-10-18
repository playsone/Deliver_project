// package_pickup_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ต้องแน่ใจว่าคุณมีไฟล์นี้:
import 'package:delivery_project/page/order_status_page.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);
const Color _accentColor = Color(0xFF0D47A1); // New accent color for details

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
  // NEW: เพิ่มข้อมูลผู้ส่ง/ไรเดอร์เข้ามาใน Model สำหรับการกรอง Client-side
  UserInfo? senderInfo;
  UserInfo? riderInfo;

  PackageModel({
    required this.id,
    required this.source,
    required this.destination,
    required this.currentStatus,
    required this.customerId,
    this.riderId,
    required this.orderDetails,
    this.deliveredImageUrl,
    this.senderInfo,
    this.riderInfo,
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
// User Info Model (สำหรับดึงชื่อและเบอร์โทร)
// ------------------------------------------------------------------
class UserInfo {
  final String name;
  final String phone;
  UserInfo(this.name, this.phone);
}

// ------------------------------------------------------------------
// Controller (สำหรับการจัดการข้อมูลและการค้นหา)
// ------------------------------------------------------------------
class PackagePickupController extends GetxController {
  final String uid;
  final RxString userPhone = ''.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchText = ''.obs;
  final RxBool isSearching = false.obs; // สถานะการโหลดค้นหา

  PackagePickupController(this.uid);

  @override
  void onInit() {
    _fetchUserPhone();
    super.onInit();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
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

  // ฟังก์ชันที่ถูกเรียกเมื่อกดปุ่มค้นหา
  Future<void> performSearch() async {
    isSearching.value = true;
    // ใช้ delay สั้นๆ เพื่อให้ UI มีเวลาแสดงสถานะกำลังโหลด
    await Future.delayed(const Duration(milliseconds: 100));
    searchText.value = searchController.text.trim();
    isSearching.value = false;
  }

  // 1. ฟังก์ชัน Stream สำหรับดึงพัสดุที่ถูกส่งมายังผู้ใช้คนนี้ (ผ่านเบอร์โทร)
  Stream<QuerySnapshot> getRecipientPackagesStream() {
    if (userPhone.value.isEmpty) {
      return Stream.empty();
    }

    final baseQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryAddress.receiverPhone', isEqualTo: userPhone.value);

    return baseQuery.snapshots();
  }

  // 2. ฟังก์ชันสำหรับดึงชื่อและเบอร์โทรผู้ใช้ (ผู้ส่ง/ไรเดอร์) จาก UID
  Future<UserInfo> getUserInfo(String? userId, String defaultName) async {
    if (userId == null || userId.isEmpty) return UserInfo(defaultName, '-');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserInfo(doc.data()?['fullname'] ?? defaultName,
            doc.data()?['phone'] ?? '-');
      }
      return UserInfo(defaultName, '-');
    } catch (e) {
      return UserInfo(defaultName, '-');
    }
  }

  // 3. ฟังก์ชันสำหรับอัพเดทสถานะเป็น 'completed' (ถูกเอาออกจาก UI แต่ยังคงไว้ใน Controller)
  Future<void> confirmPackageReception(String orderId) async {
    // ฟังก์ชันนี้ไม่ได้ถูกเรียกใช้แล้วหลังจากเอาปุ่มออก
    // แต่ยังคงไว้ในกรณีที่ต้องมีการยืนยันผ่านช่องทางอื่น
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
                  // ใช้ Obx เพื่อรอให้ userPhone ถูกโหลดก่อน และจัดการสถานะค้นหา
                  Obx(() {
                    // ตรวจสอบสถานะโหลด: 1. กำลังดึงเบอร์โทรผู้ใช้, 2. กำลังทำการค้นหา
                    if (controller.userPhone.value.isEmpty ||
                        controller.isSearching.value) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: _primaryColor),
                            SizedBox(height: 10),
                            Text('กำลังโหลดข้อมูล...')
                          ],
                        ),
                      ));
                    }
                    // เรียกใช้ StreamBuilder
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

        final allPackages = snapshot.data!.docs
            .map((doc) => PackageModel.fromFirestore(doc))
            .toList();
        final filterText = controller.searchText.value.toLowerCase();

        // ถ้ามีคำค้นหา จะต้องทำการดึงข้อมูลผู้ส่ง/ไรเดอร์ล่วงหน้าเพื่อใช้ในการกรอง
        if (filterText.isNotEmpty) {
          return FutureBuilder<List<PackageModel>>(
            future: _fetchNamesAndFilter(controller, allPackages, filterText),
            builder: (context, filterSnapshot) {
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              final filteredPackages = filterSnapshot.data ?? [];
              return _buildFilteredPackageList(controller, filteredPackages);
            },
          );
        }

        // หากไม่มีคำค้นหา: แสดงรายการทั้งหมด และใช้ FutureBuilder ภายในรายการเพื่อดึงชื่อ/เบอร์โทร
        return Column(
          children: allPackages.map((package) {
            return FutureBuilder<Map<String, String>>(
              future:
                  _fetchNames(controller, package.customerId, package.riderId),
              builder: (context, nameSnapshot) {
                return _buildPackageItemFromFuture(
                    package, nameSnapshot, controller);
              },
            );
          }).toList(),
        );
      },
    );
  }

  /// ดึงชื่อผู้ส่งและไรเดอร์พร้อมกัน
  Future<Map<String, String>> _fetchNames(PackagePickupController controller,
      String customerId, String? riderId) async {
    final senderInfo = await controller.getUserInfo(customerId, 'ผู้ส่ง');
    final riderInfo = riderId != null
        ? await controller.getUserInfo(riderId, 'ไรเดอร์')
        : UserInfo('ยังไม่มีไรเดอร์', '-');

    return {
      // ใช้ '|' เป็นตัวคั่นเพื่อให้สามารถแยกชื่อและเบอร์โทรใน UI ได้
      'sender': '${senderInfo.name}|${senderInfo.phone}',
      'rider': '${riderInfo.name}|${riderInfo.phone}',
    };
  }

  // ฟังก์ชันที่ใช้ดึงชื่อผู้ส่ง/ไรเดอร์ และกรองข้อมูล
  Future<List<PackageModel>> _fetchNamesAndFilter(
      PackagePickupController controller,
      List<PackageModel> allPackages,
      String filterText) async {
    final filteredList = <PackageModel>[];
    final lowerCaseFilter = filterText.toLowerCase();

    for (var package in allPackages) {
      // ดึงข้อมูลผู้ส่ง/ไรเดอร์
      final senderInfo =
          await controller.getUserInfo(package.customerId, 'ผู้ส่ง');
      final riderInfo = package.riderId != null
          ? await controller.getUserInfo(package.riderId, 'ไรเดอร์')
          : UserInfo('ยังไม่มีไรเดอร์', '-');

      // ตรวจสอบเงื่อนไขการค้นหา
      bool matches = false;

      // 1. ตรวจสอบรหัสพัสดุ
      if (package.id.toLowerCase().contains(lowerCaseFilter)) matches = true;

      // 2. ตรวจสอบชื่อ/เบอร์โทรผู้ส่ง
      if (senderInfo.name.toLowerCase().contains(lowerCaseFilter) ||
          senderInfo.phone.contains(lowerCaseFilter)) matches = true;

      // 3. ตรวจสอบชื่อ/เบอร์โทรไรเดอร์
      if (riderInfo.name.toLowerCase().contains(lowerCaseFilter) ||
          riderInfo.phone.contains(lowerCaseFilter)) matches = true;

      // 4. ตรวจสอบรายละเอียดสินค้า
      if (package.orderDetails.toLowerCase().contains(lowerCaseFilter))
        matches = true;

      if (matches) {
        // อัปเดต Model ด้วยข้อมูลผู้ส่ง/ไรเดอร์ที่เพิ่งดึงมา เพื่อให้ UI ใช้ได้ทันที
        package.senderInfo = senderInfo;
        package.riderInfo = riderInfo;
        filteredList.add(package);
      }
    }
    return filteredList;
  }

  // ฟังก์ชันที่สร้างรายการเมื่อมีการค้นหา
  Widget _buildFilteredPackageList(
      PackagePickupController controller, List<PackageModel> filteredPackages) {
    if (filteredPackages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 50.0),
          child: Text(
            'ไม่พบรายการพัสดุที่ตรงกับคำค้นหา',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children: filteredPackages.map((package) {
        // ใช้ข้อมูลที่ถูกตั้งค่าไว้ใน _fetchNamesAndFilter แล้ว
        final senderInfo = package.senderInfo!;
        final riderInfo = package.riderInfo!;
        return _buildPackageItem(
          package,
          _getStatusText(package.currentStatus),
          _getStatusColor(package.currentStatus),
          false, // เอาปุ่มยืนยันออก
          senderInfo.name,
          senderInfo.phone,
          riderInfo.name,
          riderInfo.phone,
          controller.confirmPackageReception,
          uid,
          role,
        );
      }).toList(),
    );
  }

  // ฟังก์ชันย่อยสำหรับสร้าง Item (กรณีไม่มีการค้นหา)
  Widget _buildPackageItemFromFuture(
    PackageModel package,
    AsyncSnapshot<Map<String, String>> nameSnapshot,
    PackagePickupController controller,
  ) {
    if (nameSnapshot.connectionState == ConnectionState.waiting) {
      // แสดงสถานะโหลดเฉพาะรายการเดียว
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator()));
    }

    String senderInfo = nameSnapshot.data?['sender'] ?? 'กำลังโหลด...';
    String riderInfo = nameSnapshot.data?['rider'] ?? 'กำลังโหลด...';

    final senderParts = senderInfo.split('|');
    final riderParts = riderInfo.split('|');

    return _buildPackageItem(
      package,
      _getStatusText(package.currentStatus),
      _getStatusColor(package.currentStatus),
      false, // เอาปุ่มยืนยันออก
      senderParts[0],
      senderParts.length > 1 ? senderParts[1] : '-',
      riderParts[0],
      riderParts.length > 1 ? riderParts[1] : '-',
      controller.confirmPackageReception,
      uid,
      role,
    );
  }

  // Helper สำหรับดึง Status Text
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอไรเดอร์รับงาน';
      case 'assigned':
        return 'ไรเดอร์รับงานแล้ว';
      case 'picked_up':
        return 'รับพัสดุแล้ว';
      case 'in_transit':
        return 'กำลังนำส่ง';
      case 'delivered':
        return 'จัดส่งสำเร็จ';
      case 'completed':
        return 'ได้รับสินค้าแล้ว ✔️';
      default:
        return 'สถานะไม่ทราบ';
    }
  }

  // Helper สำหรับดึง Status Color (ปรับปรุงสี Completed/Delivered ให้เป็นสีเดียว)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blueGrey;
      case 'assigned':
        return Colors.orange;
      case 'picked_up':
        return Colors.amber.shade800;
      case 'in_transit':
        return Colors.amber.shade800;
      case 'delivered':
        return Colors.green.shade600; // ใช้สีเข้มขึ้น
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // 5. Widget แสดงรายการพัสดุ (ปรับปรุงให้แสดงชื่อผู้ส่ง/ไรเดอร์ + รูปหลักฐาน + ตัดปุ่มออก)
  Widget _buildPackageItem(
      PackageModel package,
      String statusText,
      Color statusColor,
      bool showConfirmButton, // NOTE: Removed the confirmation logic
      String senderName,
      String senderPhone,
      String riderName,
      String riderPhone,
      Function(String) onConfirm,
      String currentUid,
      int currentRole) {
    // ตรวจสอบว่าควรแสดงรูปหลักฐานหรือไม่ (สำหรับ delivered/completed)
    final bool showDeliveredImage = (package.currentStatus == 'delivered' ||
            package.currentStatus == 'completed') &&
        package.deliveredImageUrl?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 5, // เพิ่มเงา
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          // ไปหน้า OrderStatusPage เมื่อกด
          Get.to(() => OrderStatusPage(
              orderId: package.id, uid: currentUid, role: currentRole));
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------ แถวหลัก (สถานะ) ------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: _primaryColor),
                      const SizedBox(width: 8),
                      Text(
                          'พัสดุ: ${package.orderDetails.length > 30 ? package.orderDetails.substring(0, 30) + '...' : package.orderDetails}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor)),
                    ],
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
              const Divider(height: 15, thickness: 1),

              // ------------------ รายละเอียดพัสดุ/ผู้ติดต่อ ------------------

              // ผู้ส่ง
              _buildDetailRow(Icons.person, 'ผู้ส่ง:', senderName, senderPhone),

              // ไรเดอร์
              _buildDetailRow(Icons.two_wheeler_outlined, 'ไรเดอร์:', riderName,
                  riderPhone),

              // รหัสพัสดุ
              _buildDetailRow(Icons.qr_code, 'รหัสพัสดุ:', package.id, null),

              // ------------------ รูปภาพหลักฐาน (ถ้ามี) ------------------
              if (showDeliveredImage)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text('หลักฐานการจัดส่งสำเร็จ:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        package.deliveredImageUrl!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Detail Row (Improved look)
  Widget _buildDetailRow(
      IconData icon, String title, String name, String? phone) {
    String detailText = phone != null && phone != '-'
        ? '$name (Tel: $phone)'
        : (name.isEmpty || name == 'ไม่ระบุรายละเอียดสินค้า'
            ? 'ไม่ระบุ'
            : name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _accentColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 80, // กำหนดความกว้างของ Title
            child: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Text(detailText,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          ),
        ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        decoration: InputDecoration(
          hintText: 'ค้นหาด้วยชื่อ/เบอร์โทร หรือ รหัสพัสดุ',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: _primaryColor),
          suffixIcon: IconButton(
            // ปุ่มค้นหา
            icon: const Icon(Icons.send, color: _primaryColor),
            onPressed: controller.performSearch,
          ),
        ),
        onSubmitted: (_) => controller.performSearch(),
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
