// package_delivery_page.dart

import 'package:delivery_project/page/home_rider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ต้อง Import Package model จาก home_rider.dart
// import 'home_rider.dart';

// ------------------------------------------------------------------
// Enum เพื่อจัดการสถานะการจัดส่ง
// ------------------------------------------------------------------
enum DeliveryStatus {
  // หน้าจอที่ 1: สถานะเริ่มรับงาน
  pendingPickup,
  // หน้าจอที่ 2: สถานะยืนยันการรับสินค้าจากผู้ส่ง (ถ่ายรูป)
  pickedUp,
  // หน้าจอที่ 3: สถานะกำลังนำส่ง
  inTransit,
  // หน้าจอที่ 4: สถานะถึงที่หมายและรอการยืนยันการส่ง
  deliveryCompleted,
}

// ------------------------------------------------------------------
// หน้าจอหลักของขั้นตอนการจัดส่ง
// ------------------------------------------------------------------
class PackageDeliveryPage extends StatefulWidget {
  // รับข้อมูลพัสดุผ่าน GetX Arguments
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
  // ตั้งสถานะเริ่มต้น (หรืออาจจะดึงจาก API)
  DeliveryStatus _currentStatus = DeliveryStatus.pendingPickup;
  // สำหรับการจำลอง: อาจจะดึงสถานะจริงจาก widget.package.status

  @override
  void initState() {
    super.initState();
    // ถ้าต้องการเริ่มจากสถานะอื่นตามข้อมูลพัสดุจริง
    // if (widget.package.status == 'รับสินค้าแล้ว') {
    //   _currentStatus = DeliveryStatus.inTransit;
    // }
  }

  // ฟังก์ชันสำหรับเปลี่ยนสถานะไปขั้นต่อไป
  void _moveToNextStatus() {
    setState(() {
      switch (_currentStatus) {
        case DeliveryStatus.pendingPickup:
          _currentStatus = DeliveryStatus.pickedUp;
          break;
        case DeliveryStatus.pickedUp:
          _currentStatus = DeliveryStatus.inTransit;
          break;
        case DeliveryStatus.inTransit:
          _currentStatus = DeliveryStatus.deliveryCompleted;
          break;
        case DeliveryStatus.deliveryCompleted:
          // สถานะสุดท้าย: อาจจะนำทางกลับไปหน้า Home หรือหน้า History
          Get.back(); // กลับไปหน้าก่อนหน้า (Home)
          Get.snackbar('เสร็จสิ้น', 'ดำเนินการจัดส่งเสร็จสมบูรณ์');
          break;
      }
    });
  }

  // ฟังก์ชันสำหรับจัดการการยกเลิก/ยืนยันการส่ง
  void _handleFinalAction(bool isConfirm) {
    if (isConfirm) {
      _moveToNextStatus(); // คือการส่งเสร็จสมบูรณ์
    } else {
      // TODO: จัดการการยกเลิกการจัดส่ง
      Get.snackbar('ยกเลิก', 'กำลังยกเลิกการจัดส่ง');
    }
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดสีหลัก
    const Color primaryColor = Color(0xFFC70808);
    const Color successColor = Color(0xFF38B000);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('สถานะการจัดส่ง'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. แถบสถานะด้านบน
          _buildStatusTracker(primaryColor),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  // 2. แผนที่ (จำลองด้วย Container)
                  _buildMapSection(),

                  const SizedBox(height: 20),

                  // 3. ส่วนดำเนินการหลัก (แตกต่างตามสถานะ)
                  _buildActionSection(primaryColor, successColor),

                  const SizedBox(height: 20),

                  // 4. ข้อมูลไรเดอร์
                  _buildRiderInfoSection(),

                  const SizedBox(height: 20),

                  // 5. ข้อมูลสินค้า
                  _buildPackageInfoSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ------------------------------------------------------------------
  // UI Components
  // ------------------------------------------------------------------

  Widget _buildStatusTracker(Color primaryColor) {
    // ไอคอนและสถานะสำหรับแถบด้านบน
    final List<Map<String, dynamic>> steps = [
      {'icon': Icons.location_on, 'status': DeliveryStatus.pendingPickup},
      {'icon': Icons.photo_camera, 'status': DeliveryStatus.pickedUp},
      {'icon': Icons.rv_hookup, 'status': DeliveryStatus.inTransit},
      {'icon': Icons.check_circle, 'status': DeliveryStatus.deliveryCompleted},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: steps.map((step) {
          bool isActive =
              _currentStatus.index >= (step['status'] as DeliveryStatus).index;
          return Column(
            children: [
              Icon(
                step['icon'] as IconData,
                color: isActive ? Colors.white : Colors.white54,
                size: 30,
              ),
              // สามารถเพิ่ม Text บอกสถานะย่อยได้ถ้าต้องการ
              // Text('...', style: TextStyle(color: isActive ? Colors.white : Colors.white54)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. แผนที่จำลอง
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            //  // อาจใช้รูปแผนที่จำลอง
            child: Center(
              child: Text(
                'แผนที่นำทาง (จำลอง)',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),

          // 2. สถานะการถ่ายรูป/นำทางด้านล่างแผนที่
          if (_currentStatus == DeliveryStatus.pendingPickup ||
              _currentStatus == DeliveryStatus.inTransit)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconAction('สถานะที่จัดส่ง', Icons.location_pin),
                    _buildIconAction('ถ่ายรูปสินค้า', Icons.camera_alt),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconAction(String text, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xFFC70808)),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildActionSection(Color primaryColor, Color successColor) {
    // หน้าจอที่ 4: ยืนยันการส่งเสร็จสิ้น
    if (_currentStatus == DeliveryStatus.deliveryCompleted) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            const Text(
              'จัดส่งสินค้าเรียบร้อยแล้ว?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFinalActionButton(
                    'ยกเลิก', Colors.red, () => _handleFinalAction(false)),
                const SizedBox(width: 10),
                _buildFinalActionButton(
                    'ยืนยัน', successColor, () => _handleFinalAction(true)),
              ],
            ),
          ],
        ),
      );
    }

    // หน้าจอที่ 1, 2, 3: ปุ่มดำเนินการหลัก
    String buttonText;
    if (_currentStatus == DeliveryStatus.pendingPickup) {
      buttonText = 'ยืนยันการรับสินค้า';
    } else if (_currentStatus == DeliveryStatus.pickedUp) {
      buttonText = 'เริ่มนำส่ง';
    } else {
      // DeliveryStatus.inTransit
      buttonText = 'ยืนยันการถึงที่หมาย';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _moveToNextStatus,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFinalActionButton(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRiderInfoSection() {
    return _buildInfoBox(
      title: 'ข้อมูลคนขับ',
      children: [
        _buildInfoRow(
          icon: Icons.two_wheeler,
          label: 'ชื่อ',
          value: 'คุณ พ่อครูกรัน (Rider)',
        ),
        _buildInfoRow(
          icon: Icons.phone,
          label: 'โทร',
          value: '081-949-4xxx',
        ),
      ],
    );
  }

  Widget _buildPackageInfoSection() {
    return _buildInfoBox(
      title: 'ข้อมูลสินค้า',
      children: [
        _buildInfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'สินค้า',
          value: widget.package.title,
        ),
        _buildInfoRow(
          icon: Icons.location_on,
          label: 'สถานที่',
          value: widget.package.location,
        ),
        _buildInfoRow(
          icon: Icons.person,
          label: 'ผู้รับ',
          value: widget.package.receiver,
        ),
      ],
    );
  }

  Widget _buildInfoBox(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFC70808),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 15),
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
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $value',
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                // Text(value, style: const TextStyle(fontSize: 15, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ใช้ Bottom Bar เดิมจากหน้า Home เพื่อความต่อเนื่อง
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
          // TODO: เพิ่มการนำทางสำหรับรายการอื่น ๆ
        },
      ),
    );
  }
}
