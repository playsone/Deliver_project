// history_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/history_detail_page.dart'; // **เพิ่ม:** Import หน้ารายละเอียด
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class HistoryPage extends StatefulWidget {
  final String uid;
  final int role;
  const HistoryPage({super.key, required this.uid, required this.role});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // ตั้งค่า locale สำหรับการจัดรูปแบบวันที่และเวลาเป็นภาษาไทย
    initializeDateFormatting('th', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('ประวัติการส่งสินค้า',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true, // แสดงปุ่ม Back
      ),
      body: Column(
        children: [
          // **ส่วนที่เพิ่มเข้ามา: ใช้ StreamBuilder เพื่อดึงข้อมูลประวัติ**
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Query ข้อมูลเฉพาะออเดอร์ที่ "ส่งสำเร็จแล้ว" (delivered) ของ User คนนี้
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: widget.uid)
                  .where('currentStatus', isEqualTo: 'delivered')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('ยังไม่มีประวัติการส่งสินค้า'));
                }

                final orderDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: orderDocs.length,
                  itemBuilder: (context, index) {
                    final doc = orderDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final pickupAddress =
                        data['pickupAddress'] as Map<String, dynamic>? ?? {};
                    final deliveryAddress =
                        data['deliveryAddress'] as Map<String, dynamic>? ?? {};
                    final timestamp =
                        (data['createdAt'] as Timestamp?)?.toDate();
                    final formattedDate = timestamp != null
                        ? DateFormat('dd MMM yyyy', 'th').format(timestamp)
                        : '';

                    // สร้าง UI จากข้อมูลจริง
                    return _buildHistoryItem(
                      orderId: doc.id, // **เพิ่ม:** ส่ง document ID ไปด้วย
                      locationFrom: pickupAddress['detail'] ?? 'N/A',
                      locationTo: deliveryAddress['detail'] ?? 'N/A',
                      receiverName:
                          deliveryAddress['receiverName'] ?? 'ไม่มีชื่อผู้รับ',
                      date: formattedDate,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1), // Index 1
    );
  }

  // **แก้ไข:** ปรับแก้ Widget ให้รับข้อมูลที่ต้องการแสดงผลและกดได้
  Widget _buildHistoryItem({
    required String orderId,
    required String locationFrom,
    required String locationTo,
    required String receiverName,
    required String date,
  }) {
    return InkWell(
      // **เพิ่ม:** ทำให้ Card สามารถกดได้
      onTap: () {
        // **เพิ่ม:** นำทางไปยังหน้ารายละเอียด พร้อมส่ง orderId
        Get.to(() => HistoryDetailPage(
              uid: widget.uid,
              role: widget.role,
              orderId: orderId, // ส่ง ID ของออเดอร์ที่กด
            ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            const Icon(Icons.task_alt, size: 50, color: Colors.green),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ส่งไปยัง: $receiverName',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildLocationDetail(Icons.store, 'จาก: $locationFrom'),
                  _buildLocationDetail(Icons.location_on, 'ถึง: $locationTo'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('ส่งสำเร็จ',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                Text(date,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
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
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar
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
            label: 'ประวัติ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 0) {
            Get.offAll(() => HomeScreen(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}
