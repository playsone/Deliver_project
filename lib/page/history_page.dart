// file: lib/page/history_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
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
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(isDetailPage ? 'รายละเอียดประวัติ' : 'ประวัติการส่งสินค้า',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: isDetailPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedOrderId = null;
                  });
                },
              )
            : null,
        automaticallyImplyLeading: !isDetailPage,
      ),
      body: isDetailPage
          ? _buildOrderDetailView(_selectedOrderId!)
          : _buildOrderListView(),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1),
    );
  }

  // ===================================================================
  // == WIDGETS สำหรับแสดง "หน้ารายการประวัติ" ==
  // ===================================================================

  Widget _buildOrderListView() {
    return StreamBuilder<QuerySnapshot>(
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
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีประวัติการส่งสินค้า'));
        }

        final orderDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: orderDocs.length,
          itemBuilder: (context, index) {
            final doc = orderDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final deliveryAddress =
                data['deliveryAddress'] as Map<String, dynamic>? ?? {};
            final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
            final formattedDate = timestamp != null
                ? DateFormat('dd MMM yyyy', 'th').format(timestamp)
                : '';

            return _buildHistoryItem(
              orderId: doc.id,
              receiverName:
                  deliveryAddress['receiverName'] ?? 'ไม่มีชื่อผู้รับ',
              date: formattedDate,
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryItem({
    required String orderId,
    required String receiverName,
    required String date,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrderId = orderId;
        });
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
            const Icon(Icons.task_alt, size: 40, color: Colors.green),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ส่งถึง: $receiverName',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'วันที่: $date',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // == WIDGETS สำหรับแสดง "หน้ารายละเอียดประวัติ" ==
  // ===================================================================

  // --- ⭐️ แก้ไข: เพิ่ม StreamBuilder สำหรับดึงข้อมูล Rider ---
  Widget _buildOrderDetailView(String orderId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Center(child: Text('ไม่พบข้อมูลออเดอร์'));
        }

        final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        final riderId = orderData['riderId'] as String?;

        // ถ้ายังไม่มี Rider ให้แสดงข้อมูลออเดอร์ไปก่อน
        if (riderId == null || riderId.isEmpty) {
          return _buildContent(orderData, null);
        }

        // ถ้ามี Rider ID, ให้ดึงข้อมูลของ Rider มาด้วย
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(riderId)
              .snapshots(),
          builder: (context, riderSnapshot) {
            final riderData =
                riderSnapshot.data?.data() as Map<String, dynamic>?;
            return _buildContent(orderData, riderData);
          },
        );
      },
    );
  }

  // --- ⭐️ แก้ไข: เพิ่ม riderData เป็นพารามิเตอร์ ---
  Widget _buildContent(
      Map<String, dynamic> orderData, Map<String, dynamic>? riderData) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(
              orderData, riderData), // ส่ง riderData ไปด้วย
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- ⭐️ แก้ไข: เพิ่ม riderData และเรียก Widget แสดงข้อมูล Rider ---
  Widget _buildCurrentStatusHeader(
      Map<String, dynamic> orderData, Map<String, dynamic>? riderData) {
    final status = orderData['currentStatus'] ?? 'unknown';
    final orderDetails = orderData['orderDetails'] ?? 'ไม่มีรายละเอียด';
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final receiverName = deliveryAddress['receiverName'] ?? 'ไม่มีข้อมูล';
    final receiverPhone = deliveryAddress['receiverPhone'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderDetails,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('สถานะ: ',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _translateStatus(status),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          const Text('ข้อมูลผู้รับ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('ชื่อ: $receiverName'),
          Text('เบอร์โทร: $receiverPhone'),

          // --- ⭐️ เพิ่ม: เรียกใช้ Widget แสดงข้อมูล Rider ---
          if (riderData != null) ...[
            const Divider(height: 20),
            _buildRiderInfoSection(riderData),
          ],

          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- ⭐️ เพิ่ม: Widget ใหม่สำหรับแสดงข้อมูล Rider ---
  Widget _buildRiderInfoSection(Map<String, dynamic> riderData) {
    final riderName = riderData['fullname'] ?? 'ไม่มีข้อมูล';
    final riderPhone = riderData['phone'] ?? '-';
    final vehicleNo = riderData['vehicle_no'] ??
        '-'; // ตรวจสอบ field name ให้ตรงกับ Firestore

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ข้อมูลไรเดอร์',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('ชื่อ: $riderName'),
        Text('เบอร์โทร: $riderPhone'),
        Text('ทะเบียนรถ: $vehicleNo'),
      ],
    );
  }

  // (โค้ดส่วนที่เหลือไม่มีการเปลี่ยนแปลง)
  Widget _buildStatusTimeline(List<dynamic> statusHistory) {
    if (statusHistory.isEmpty) {
      return const Center(child: Text('ไม่มีประวัติสถานะ'));
    }
    statusHistory.sort((a, b) =>
        (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statusHistory.length,
      itemBuilder: (context, index) {
        final history = statusHistory[index] as Map<String, dynamic>;
        final status = history['status'] as String;
        final timestamp = (history['timestamp'] as Timestamp?)?.toDate();
        final imageUrl = history['imgOfStatus'] as String?;
        final formattedTime = timestamp != null
            ? DateFormat('dd MMM yyyy, HH:mm', 'th').format(timestamp)
            : 'ไม่มีข้อมูลเวลา';
        bool isFirst = index == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    isFirst
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    color: isFirst ? _getStatusColor(status) : Colors.grey,
                    size: 20,
                  ),
                  if (index != statusHistory.length - 1)
                    Container(
                        height: (imageUrl != null && imageUrl.isNotEmpty)
                            ? 120
                            : 40,
                        width: 2,
                        color: Colors.grey.shade300)
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translateStatus(status),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isFirst ? FontWeight.bold : FontWeight.normal,
                        color: isFirst ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                    Text(formattedTime,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              imageUrl,
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                return progress == null
                                    ? child
                                    : const SizedBox(
                                        height: 100,
                                        width: 100,
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error,
                                    color: Colors.red);
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              panEnabled: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        );
      },
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'รอไรเดอร์รับงาน';
      case 'accepted':
        return 'ไรเดอร์รับงานแล้ว';
      case 'picked_up':
        return 'รับพัสดุแล้ว';
      case 'in_transit':
        return 'กำลังนำส่ง';
      case 'delivered':
        return 'จัดส่งสำเร็จ';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'accepted':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

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
