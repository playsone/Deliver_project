// history_page.dart

import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class HistoryPage extends StatelessWidget {
  final String uid;
  const HistoryPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildHistoryTitle(),
              const SizedBox(height: 10),
              // รายการประวัติการจัดส่ง (Hardcoded Data)
              _buildHistoryItem(
                'กองพัฒนานักศึกษา',
                'หอพักอาณาจักรฟ้า',
                'ส่งสำเร็จ',
                const Color(0xFF4CAF50), // สีเขียว
              ),
              _buildHistoryItem(
                'กองบริการการศึกษา',
                'หอพักอาณาจักรฟ้า',
                'อยู่ระหว่างส่ง',
                const Color(0xFFFF9800), // สีส้ม
              ),
              _buildHistoryItem(
                'คณะวิทยาศาสตร์',
                'หอพักอาณาจักรฟ้า',
                'ส่งสำเร็จ',
                const Color(0xFF4CAF50),
              ),
              _buildHistoryItem(
                'ร้านค้าหน้า ม.',
                'หอพักอาณาจักรฟ้า',
                'ส่งสำเร็จ',
                const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1), // Index 1
    );
  }

  // ส่วน Header (คล้าย home.dart)
  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Background Wave/ClipPath
        ClipPath(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: const BoxDecoration(color: _primaryColor),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'สวัสดีคุณ\nพ่อครูกรัน',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // TODO: Go to Profile Options
                    },
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          NetworkImage('https://picsum.photos/200'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildLocationBar(),
            ],
          ),
        ),
      ],
    );
  }

  /// สร้างแถบค้นหา
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: _primaryColor, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหา 0814715566',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้างแถบที่อยู่
  Widget _buildLocationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor, // ใช้สีเข้มเพื่อให้เด่น
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'หอพักอาณาจักรฟ้า',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ส่วนหัวข้อ "ประวัติการส่งสินค้า"
  Widget _buildHistoryTitle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        decoration: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, offset: Offset(0, 4), blurRadius: 6),
          ],
        ),
        child: const Text(
          'ประวัติการส่งสินค้า',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget สำหรับรายการประวัติแต่ละชิ้น
  Widget _buildHistoryItem(String locationFrom, String locationTo,
      String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          // Icon/Image ส่วนซ้าย
          const Icon(
            Icons.two_wheeler,
            size: 60,
            color: Colors.black,
          ),
          const SizedBox(width: 15),
          // รายละเอียด
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationDetail(
                  Icons.store,
                  'ต้นทาง: $locationFrom',
                ),
                _buildLocationDetail(
                  Icons.location_on,
                  'ปลายทาง: $locationTo',
                ),
                _buildLocationDetail(
                  Icons.person,
                  'ผู้รับ: ________',
                ),
              ],
            ),
          ),
          // สถานะปุ่มขวา
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // Bottom Navigation Bar (อ้างอิงจาก home.dart)
  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
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
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 0) {
            Get.to(() => HomeScreen(
                  uid: uid,
                )); // สมมติว่าหน้า Home ถูกกำหนดเป็น '/'
          } else if (index == 2) {
            Get.off(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}
