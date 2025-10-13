import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/index.dart';
// ***** เพิ่ม Import หน้าขั้นตอนการจัดส่ง (สมมติว่าคุณได้สร้างไฟล์นี้แล้ว) *****
import 'package_delivery_page.dart';

// ------------------------------------------------------------------
// Model Data (จำลองโครงสร้างข้อมูลสินค้าที่จะได้จาก API)
// ------------------------------------------------------------------
class Package {
  final String title;
  final String location;
  final String status;
  final String imagePath;
  final String destination;
  final String receiver;

  Package({
    required this.title,
    required this.location,
    required this.status,
    required this.imagePath,
    required this.destination,
    required this.receiver,
  });
}

// ข้อมูลจำลอง
final List<Package> mockPackages = [
  Package(
    title: 'พัสดุวิชาการสารสนเทศ',
    location: 'หอพักอาณาจักรฟ้า',
    status: 'รอรับสินค้า',
    imagePath: 'assets/images/package1.png', // ต้องเพิ่มรูปภาพ
    destination: 'รหัส donner:1',
    receiver: 'คุณ...',
  ),
  Package(
    title: 'น้ำหอมผู้ชาย',
    location: 'หอพักอาณาจักรฟ้า',
    status: 'จัดส่งสำเร็จ',
    imagePath: 'assets/images/package2.png',
    destination: 'รหัส donner:2',
    receiver: 'คุณ...',
  ),
  Package(
    title: 'เครื่องปริ้นท์เตอร์',
    location: 'หอพักอาณาจักรฟ้า',
    status: 'รับสินค้าแล้ว',
    imagePath: 'assets/images/package3.png',
    destination: 'รหัส donner:3',
    receiver: 'คุณ...',
  ),
  Package(
    title: 'กล่องพัสดุขนาดใหญ่',
    location: 'หอพักอาณาจักรฟ้า',
    status: 'รอรับสินค้า',
    imagePath: 'assets/images/package4.png',
    destination: 'รหัส donner:4',
    receiver: 'คุณ...',
  ),
];

// ------------------------------------------------------------------
// Rider Home Screen
// ------------------------------------------------------------------

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9), // สีพื้นหลังตามรูป
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildContentHeader(),
            Expanded(
              child: _buildPackageList(), // รายการสินค้า
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  //------------------------------------------------------------------
  // Header Section
  //------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'สวัสดีคุณ พ่อครูกรัน',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // รูปโปรไฟล์ไรเดอร์
          GestureDetector(
            onTap: () {
              // อาจจะมีเมนูสำหรับไรเดอร์โดยเฉพาะ
              _showProfileOptions(context);
            },
            child: const CircleAvatar(
              radius: 30,
              // ใช้ NetworkImage สำหรับรูปโปรไฟล์ (ต้องมี URL จริง)
              backgroundImage: NetworkImage('https://picsum.photos/200'),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนหัวรายการสินค้า (รายการสินค้า)
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
      child: const Text(
        'รายการสินค้า',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  //------------------------------------------------------------------
  // Package List Section
  //------------------------------------------------------------------

  Widget _buildPackageList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: mockPackages.length,
      itemBuilder: (context, index) {
        final package = mockPackages[index];
        return _buildPackageCard(context, package);
      },
    );
  }

  Widget _buildPackageCard(BuildContext context, Package package) {
    // กำหนดว่าพัสดุนี้สามารถดำเนินการได้หรือไม่ (ไม่ใช่ 'จัดส่งสำเร็จ' แล้ว)
    bool isActionable = package.status != 'จัดส่งสำเร็จ';
    // ใช้ isActionable แทน isPending ในการแสดงผลปุ่ม

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูปภาพสินค้า (ใช้ Icon แทน Image.asset ถ้าไม่มีรูปภาพจริงใน assets)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 35,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFC70808),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildPackageDetailRow(Icons.location_on, package.location),
                  _buildPackageDetailRow(Icons.qr_code, package.destination),
                  _buildPackageDetailRow(Icons.person, package.receiver),
                ],
              ),
            ),
            // ปุ่มดำเนินการ
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  // ***** แก้ไข: Action เมื่อกดปุ่ม (นำทางไปหน้าขั้นตอนการจัดส่ง) *****
                  if (isActionable) {
                    Get.to(() => PackageDeliveryPage(package: package));
                  } else {
                    // สำหรับสถานะ 'จัดส่งสำเร็จ'
                    Get.snackbar('ข้อมูล', 'พัสดุนี้จัดส่งสำเร็จแล้ว');
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: isActionable
                      ? const Color(0xFF38B000)
                      : Colors.grey, // สีเขียวหรือเทา
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // เปลี่ยนข้อความปุ่มตามสถานะที่ดำเนินการได้หรือไม่
                      isActionable ? 'ดำเนินการ' : 'เสร็จสิ้น',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
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
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808), // สีแดงเข้มตามรูป
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, -2),
            blurRadius: 5,
          ),
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
          if (index == 2) {
            Get.offAll(() => const SpeedDerApp()); // ออกจากระบบ
          }
          // TODO: เพิ่มการนำทางสำหรับรายการอื่น ๆ
        },
      ),
    );
  }

  //------------------------------------------------------------------
  // Profile Options Modal (นำมาจากโค้ดก่อนหน้า)
  //------------------------------------------------------------------

  void _showProfileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
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
                  color: Colors.grey,
                ),
              ),
              _buildOptionButton(
                context,
                'แก้ไขข้อมูลส่วนตัว',
                Icons.person_outline,
                () {
                  Get.to(() => const EditProfilePage());
                },
              ),
              _buildOptionButton(
                context,
                'เปลี่ยนรหัสผ่าน',
                Icons.lock_outline,
                () {
                  Navigator.pop(context);
                },
              ),
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
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFFC70808)),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
