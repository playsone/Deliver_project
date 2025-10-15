import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/package_delivery_page.dart';

// ------------------------------------------------------------------
// Model Data ที่ปรับแก้ให้ตรงกับ Firestore
// ------------------------------------------------------------------
class Package {
  final String id; // ID ของเอกสารใน Firestore
  final String title;
  final String location; // ที่อยู่ต้นทาง
  final String destination; // ที่อยู่ปลายทาง
  final String? imageUrl; // URL รูปภาพสินค้า

  Package({
    required this.id,
    required this.title,
    required this.location,
    required this.destination,
    this.imageUrl,
  });
}

// ------------------------------------------------------------------
// Rider Home Screen
// ------------------------------------------------------------------

class RiderHomeScreen extends StatelessWidget {
  final String uid;
  final int role;
  const RiderHomeScreen({super.key, required this.uid, required this.role});

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
              child: _buildPackageList(), // รายการสินค้าที่ดึงข้อมูลจริง
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  //------------------------------------------------------------------
  // **ส่วนที่แก้ไข: Header ดึงข้อมูลไรเดอร์จริงมาแสดง**
  //------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // ฟังการเปลี่ยนแปลงข้อมูลของไรเดอร์ที่ล็อกอินอยู่
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        // ค่าเริ่มต้น
        String riderName = 'ไรเดอร์';
        String profileImageUrl = 'https://picsum.photos/200';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          riderName = data['fullname'] ?? 'ไรเดอร์';
          profileImageUrl = data['profile'] ?? profileImageUrl;
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFC70808),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สวัสดีคุณ $riderName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showProfileOptions(context);
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(profileImageUrl),
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ส่วนหัวรายการสินค้า
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
        'รายการงานที่รอการจัดส่ง',
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
  // Package List Section - ใช้ StreamBuilder ดึงงานที่ว่างอยู่
  //------------------------------------------------------------------

  Widget _buildPackageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('delivery_orders')
          .where('currentStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'ไม่มีงานให้รับในขณะนี้',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final orderDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: orderDocs.length,
          itemBuilder: (context, index) {
            final doc = orderDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final package = Package(
              id: doc.id,
              title: data['orderDetails'] ?? 'ไม่มีรายละเอียด',
              location: data['pickupAddress']['detail'] ?? 'ไม่มีข้อมูลต้นทาง',
              destination:
                  data['deliveryAddress']['detail'] ?? 'ไม่มีข้อมูลปลายทาง',
              imageUrl: data['orderImageUrl'],
            );

            // **ส่ง uid ของไรเดอร์ไปด้วย**
            return _buildPackageCard(context, package, uid);
          },
        );
      },
    );
  }

  // **ส่วนที่แก้ไข: แก้ไขข้อผิดพลาดทั้งหมดใน Card**
  Widget _buildPackageCard(
      BuildContext context, Package package, String riderId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: package.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(package.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: package.imageUrl == null
                  ? const Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: Colors.black54,
                    )
                  : null,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  _buildPackageDetailRow(
                      Icons.store, 'ต้นทาง: ${package.location}'),
                  _buildPackageDetailRow(
                      Icons.location_on, 'ปลายทาง: ${package.destination}'),
                ],
              ),
            ),
            // ปุ่มดำเนินการ
            Align(
              alignment: Alignment.center,
              child: TextButton(
                // **ทำให้ onPressed เป็น async เพื่อรอการอัปเดตข้อมูล**
                onPressed: () async {
                  try {
                    final orderRef = FirebaseFirestore.instance
                        .collection('delivery_orders')
                        .doc(package.id);

                    // อัปเดตเอกสารใน Firestore
                    await orderRef.update({
                      'riderId': riderId, // ใช้ riderId ที่รับเข้ามา
                      'currentStatus': 'accepted',
                      'statusHistory': FieldValue.arrayUnion([
                        {
                          'status': 'accepted',
                          'timestamp': FieldValue.serverTimestamp()
                        }
                      ]),
                    });

                    // เมื่อสำเร็จแล้วจึงนำทางไปยังหน้าต่อไป
                    Get.to(() => PackageDeliveryPage(
                          package: package,
                          uid: '',
                          role: 1,
                        ));
                  } catch (e) {
                    Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถรับงานนี้ได้');
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF38B000),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'รับงาน',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 4),
                    Icon(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Expanded(
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
        color: Color(0xFFC70808),
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
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }

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
                  // **ส่ง uid และ role ไปยังหน้าแก้ไขโปรไฟล์**
                  Get.to(() => EditProfilePage(
                        uid: uid,
                        role: role,
                      ));
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
