// package_pickup_page.dart

import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/order_status_page.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);
const Color _accentColor = Color(0xFF0D47A1);

// ------------------------------------------------------------------
// Model & Controller (ย้ายมาอยู่ในไฟล์เดียวกันเพื่อความสมบูรณ์)
// ------------------------------------------------------------------
class UserInfo {
  final String name;
  final String phone;
  UserInfo(this.name, this.phone);
}

class PackageModel {
  final String id;
  final String source;
  final String destination;
  final String currentStatus;
  final String customerId;
  final String? riderId;
  final String orderDetails;
  final String? deliveredImageUrl;
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

    String? deliveredImgUrl;
    if (data['currentStatus'] == 'delivered' ||
        data['currentStatus'] == 'completed') {
      deliveredImgUrl = data['deliveredImageUrl'];

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

class PackagePickupController extends GetxController {
  final String uid;
  final RxString userPhone = ''.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchText = ''.obs;
  final RxBool isSearching = false.obs;

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

  Future<void> performSearch() async {
    isSearching.value = true;
    await Future.delayed(const Duration(milliseconds: 100));
    searchText.value = searchController.text.trim();
    isSearching.value = false;
  }

  // Stream สำหรับดึงพัสดุที่ถูกส่งมายังผู้ใช้คนนี้ (ผ่านเบอร์โทร)
  Stream<QuerySnapshot> getRecipientPackagesStream() {
    if (userPhone.value.isEmpty) {
      return Stream.empty();
    }

    // NOTE: ลบ orderBy ออกเพื่อเลี่ยง Composite Index Error
    final baseQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryAddress.receiverPhone', isEqualTo: userPhone.value);

    return baseQuery.snapshots();
  }

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
// Page (UI) - PackagePickupPage
// ------------------------------------------------------------------
class PackagePickupPage extends StatelessWidget {
  final String uid;
  final int role; // 0 = User (Sender/Recipient), 1 = Rider
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
                  _buildSearchBar(controller),
                  const SizedBox(height: 20),
                  Obx(() {
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

  Future<Map<String, String>> _fetchNames(PackagePickupController controller,
      String customerId, String? riderId) async {
    final senderInfo = await controller.getUserInfo(customerId, 'ผู้ส่ง');
    final riderInfo = riderId != null
        ? await controller.getUserInfo(riderId, 'ไรเดอร์')
        : UserInfo('ยังไม่มีไรเดอร์', '-');

    return {
      'sender': '${senderInfo.name}|${senderInfo.phone}',
      'rider': '${riderInfo.name}|${riderInfo.phone}',
    };
  }

  Future<List<PackageModel>> _fetchNamesAndFilter(
      PackagePickupController controller,
      List<PackageModel> allPackages,
      String filterText) async {
    final filteredList = <PackageModel>[];
    final lowerCaseFilter = filterText.toLowerCase();

    for (var package in allPackages) {
      final senderInfo =
          await controller.getUserInfo(package.customerId, 'ผู้ส่ง');
      final riderInfo = package.riderId != null
          ? await controller.getUserInfo(package.riderId, 'ไรเดอร์')
          : UserInfo('ยังไม่มีไรเดอร์', '-');

      bool matches = false;

      if (package.id.toLowerCase().contains(lowerCaseFilter)) matches = true;
      if (senderInfo.name.toLowerCase().contains(lowerCaseFilter) ||
          senderInfo.phone.contains(lowerCaseFilter)) matches = true;
      if (riderInfo.name.toLowerCase().contains(lowerCaseFilter) ||
          riderInfo.phone.contains(lowerCaseFilter)) matches = true;
      if (package.orderDetails.toLowerCase().contains(lowerCaseFilter))
        matches = true;

      if (matches) {
        package.senderInfo = senderInfo;
        package.riderInfo = riderInfo;
        filteredList.add(package);
      }
    }
    return filteredList;
  }

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
        final senderInfo = package.senderInfo!;
        final riderInfo = package.riderInfo!;
        return _buildPackageItem(
          package,
          _getStatusText(package.currentStatus),
          _getStatusColor(package.currentStatus),
          false,
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

  Widget _buildPackageItemFromFuture(
    PackageModel package,
    AsyncSnapshot<Map<String, String>> nameSnapshot,
    PackagePickupController controller,
  ) {
    if (nameSnapshot.connectionState == ConnectionState.waiting) {
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
      false,
      senderParts[0],
      senderParts.length > 1 ? senderParts[1] : '-',
      riderParts[0],
      riderParts.length > 1 ? riderParts[1] : '-',
      controller.confirmPackageReception,
      uid,
      role,
    );
  }

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
        return Colors.green.shade600;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPackageItem(
      PackageModel package,
      String statusText,
      Color statusColor,
      bool showConfirmButton,
      String senderName,
      String senderPhone,
      String riderName,
      String riderPhone,
      Function(String) onConfirm,
      String currentUid,
      int currentRole) {
    final bool showDeliveredImage = (package.currentStatus == 'delivered' ||
            package.currentStatus == 'completed') &&
        package.deliveredImageUrl?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          // *** สำคัญ: ส่ง role: 0 (User/Recipient) ไปยังหน้าติดตามสถานะ ***
          // เราใช้ role 0 ที่หมายถึง User ในฐานะผู้รับ
          Get.to(() => OrderStatusPage(
              orderId: package.id, uid: currentUid, role: 0)); 
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              _buildDetailRow(Icons.person, 'ผู้ส่ง:', senderName, senderPhone),
              _buildDetailRow(
                  Icons.two_wheeler_outlined, 'ไรเดอร์:', riderName, riderPhone),
              _buildDetailRow(Icons.qr_code, 'รหัสพัสดุ:', package.id, null),
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
            width: 80,
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
          if (index == 0) {
            Get.offAll(() => HomeScreen(uid: uid, role: role));
          } else if (index == 1) {
            Get.to(() => HistoryPage(uid: uid, role: role));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}

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