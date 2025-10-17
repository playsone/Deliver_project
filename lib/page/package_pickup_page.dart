// package_pickup_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
// 1. เพิ่มการ import สำหรับ Firebase
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

// 2. สร้าง Model สำหรับ Package (ช่วยให้จัดการข้อมูลง่ายขึ้น)
class PackageModel {
  final String id;
  final String source;
  final String destination;
  final String currentStatus;

  PackageModel({
    required this.id,
    required this.source,
    required this.destination,
    required this.currentStatus,
  });

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // ดึงข้อมูล pickupAddress.detail เป็น source
    String sourceDetail = 'ไม่ระบุต้นทาง';
    if (data['pickupAddress'] != null && data['pickupAddress']['detail'] != null) {
      sourceDetail = data['pickupAddress']['detail'];
    }
    
    // ดึงข้อมูล deliveryAddress.detail เป็น destination
    String destinationDetail = 'ไม่ระบุปลายทาง';
    if (data['deliveryAddress'] != null && data['deliveryAddress']['detail'] != null) {
      destinationDetail = data['deliveryAddress']['detail'];
    }

    return PackageModel(
      id: doc.id, // ใช้ Document ID เป็นรหัสพัสดุชั่วคราว
      source: 'พัสดุจาก: $sourceDetail',
      destination: 'ปลายทาง: $destinationDetail',
      currentStatus: data['currentStatus'] ?? 'unknown',
    );
  }
}


class PackagePickupPage extends StatelessWidget {
  final String uid;
  final int role;
  const PackagePickupPage({super.key, required this.uid, required this.role});

  // 3. สร้าง Stream สำหรับดึงข้อมูลพัสดุ
  // ดึงรายการพัสดุที่ Rider คนนี้ต้องรับ (status เป็น accepted)
  Stream<QuerySnapshot> getPickupPackagesStream(String riderId) {
    // ⚠️ ถ้าเป็นหน้า "พัสดุที่ต้องรับ" ควรใช้ status ที่ Rider ต้องดำเนินการต่อ เช่น "accepted"
    // ถ้าต้องการรายการที่ส่งเสร็จแล้ว ให้เปลี่ยน where('currentStatus', isEqualTo: 'delivered')
    return FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('currentStatus', whereIn: ['accepted', 'picked_up', 'in_transit']) // สถานะที่ต้องไปรับหรือกำลังดำเนินการ
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
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
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  // 4. ใช้ StreamBuilder แทนรายการพัสดุแบบ Hardcode
                  _buildPackagesList(uid),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // 4. Widget แสดงรายการพัสดุด้วย StreamBuilder
  Widget _buildPackagesList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: getPickupPackagesStream(uid), // ใช้ Stream ที่สร้างไว้
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: Text(
                '❌ ไม่มีรายการพัสดุที่ต้องรับในขณะนี้',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        // แปลงข้อมูลจาก QuerySnapshot เป็น List<PackageModel>
        final packages = snapshot.data!.docs.map((doc) => PackageModel.fromFirestore(doc)).toList();

        return Column(
          children: packages.map((package) {
            bool isReady = package.currentStatus == 'accepted' || package.currentStatus == 'picked_up';
            // ปรับ logic การแสดงผล
            String statusText = '';
            Color statusColor = Colors.grey;
            if (package.currentStatus == 'accepted') {
                statusText = 'พร้อมรับ';
                statusColor = Colors.green;
            } else if (package.currentStatus == 'picked_up') {
                statusText = 'รับแล้ว';
                statusColor = Colors.blue;
            } else if (package.currentStatus == 'in_transit') {
                statusText = 'กำลังส่ง';
                statusColor = Colors.orange;
            } else {
                statusText = 'รอการยืนยัน';
                statusColor = Colors.grey;
            }

            return _buildPackageItem(
              package.source,
              package.destination,
              package.id,
              statusText,
              statusColor,
              isReady, // ใช้ isReady สำหรับปุ่มยืนยัน
            );
          }).toList(),
        );
      },
    );
  }

  // ** ปรับแก้ _buildPackageItem ให้รับ statusText และ statusColor **
  Widget _buildPackageItem(
      String source, 
      String destination, 
      String id, 
      String statusText, 
      Color statusColor,
      bool showConfirmButton) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Get.snackbar('รายละเอียด', 'เปิดหน้าเพื่อดูรายละเอียด/ดำเนินการพัสดุ $id');
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      source,
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
              _buildDetailRow(Icons.pin_drop, destination),
              _buildDetailRow(Icons.qr_code, 'รหัสพัสดุ: $id'),
              const SizedBox(height: 10),
              // ใช้ showConfirmButton (isReady) เพื่อแสดงปุ่ม
              if (showConfirmButton)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.snackbar('ยืนยัน', 'กดเพื่อไปหน้ายืนยันการรับ/ส่ง $id');
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('ดำเนินการ',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
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

  // --- ส่วนอื่นๆ เหมือนเดิม ---

  // ส่วน Header
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
            'พัสดุที่ต้องรับ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        background: ClipPath(
          clipper: HeaderClipper(), // ใช้ Clipper ที่กำหนดเอง
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
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'ค้นหาพัสดุด้วยรหัส หรือ ต้นทาง',
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

  // Bottom Navigation Bar (อ้างอิงจาก home.dart)
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
        currentIndex: 0, // ควรเปลี่ยนเมื่อมีการนำทางจริง
        onTap: (index) {
          // ในหน้านี้ควรกด Back
        },
      ),
    );
  }
}

// Custom Clipper สำหรับ Header (คัดลอกมาจากไฟล์อื่น)
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