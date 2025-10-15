// package_pickup_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class PackagePickupPage extends StatelessWidget {
  const PackagePickupPage({super.key});

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
                  // รายการพัสดุที่ต้องรับ
                  _buildPackageItem(
                    'พัสดุจาก: ศูนย์บริการ มข.',
                    'ปลายทาง: หอพักอาณาจักรฟ้า',
                    'รหัสพัสดุ: P001-A',
                    true, // ต้องรับวันนี้
                  ),
                  _buildPackageItem(
                    'พัสดุจาก: ร้านค้าหน้า ม.',
                    'ปลายทาง: หอพักอาณาจักรฟ้า',
                    'รหัสพัสดุ: P002-B',
                    true,
                  ),
                  _buildPackageItem(
                    'พัสดุจาก: คณะวิศวกรรมศาสตร์',
                    'ปลายทาง: บ้านพักส่วนตัว',
                    'รหัสพัสดุ: P003-C',
                    false, // รอการยืนยัน
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

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

  // Widget สำหรับรายการพัสดุที่ต้องรับ
  Widget _buildPackageItem(
      String source, String destination, String id, bool isReady) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Get.snackbar('รายละเอียด', 'เปิดหน้าเพื่อยืนยันการรับพัสดุ $id');
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    source,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReady ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isReady ? 'พร้อมรับ' : 'รอการยืนยัน',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(Icons.pin_drop, destination),
              _buildDetailRow(Icons.qr_code, id),
              const SizedBox(height: 10),
              if (isReady)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.snackbar('ยืนยัน', 'กดเพื่อไปหน้ายืนยันการรับ $id');
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('ยืนยันการรับ',
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
