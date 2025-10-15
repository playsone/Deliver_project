// rider_info_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class RiderInfoPage extends StatelessWidget {
  final String uid;
  final int role;
  const RiderInfoPage({super.key, required this.uid, required this.role});

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
                  _buildRiderCard(
                    'นาย ก. ไรเดอร์',
                    '081-XXX-XXXX',
                    'ID: R-001',
                    'กำลังจัดส่งพัสดุ 5 ชิ้น',
                    Icons.two_wheeler,
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection('ข้อมูลศูนย์จัดส่ง', [
                    _buildInfoRow(Icons.phone, 'โทรศัพท์: 02-123-4567'),
                    _buildInfoRow(Icons.email, 'อีเมล: contact@speedder.com'),
                    _buildInfoRow(
                        Icons.access_time, 'เวลาทำการ: 08:00 - 18:00 น.'),
                    _buildInfoRow(Icons.location_on,
                        'ที่อยู่: ศูนย์กระจายสินค้าหลัก (ขอนแก่น)'),
                  ]),
                  const SizedBox(height: 20),
                  _buildServiceButton(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ส่วน Header (ปรับให้เรียบง่ายขึ้น)
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
            'ข้อมูลไรเดอร์และศูนย์บริการ',
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
              'ข้อมูลไรเดอร์',
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

  // Card ข้อมูลไรเดอร์
  Widget _buildRiderCard(
      String name, String phone, String id, String status, IconData icon) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, size: 60, color: _primaryColor),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('โทร: $phone',
                      style: const TextStyle(color: Colors.grey)),
                  Text('สถานะ: $status',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.blue)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Call Action
                Get.snackbar('โทรออก', 'กำลังโทรไปยังไรเดอร์ $name');
              },
              icon: const Icon(Icons.call, color: Colors.green, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  // ส่วนข้อมูลทั่วไป
  Widget _buildInfoSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(color: Colors.grey),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details,
          ),
        ),
      ],
    );
  }

  // แถวแสดงรายละเอียด
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // ปุ่มติดต่อ
  Widget _buildServiceButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Get.snackbar('ติดต่อศูนย์', 'เปิดหน้าแชทติดต่อศูนย์บริการ...');
        },
        icon: const Icon(Icons.chat, color: Colors.white),
        label: const Text('ติดต่อศูนย์บริการ (Chat)',
            style: TextStyle(fontSize: 16, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
