// file: lib/page/history_page.dart

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

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

  /// Widget สำหรับแสดง "หน้ารายการประวัติ"
  Widget _buildOrderListView() {
    // Stream 1: ออเดอร์ที่ user เป็น "ลูกค้า" และส่งสำเร็จแล้ว
    final customerStream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.uid)
        .where('currentStatus', isEqualTo: 'delivered')
        .snapshots();

    // Stream 2: ออเดอร์ที่ user เป็น "ไรเดอร์" และส่งสำเร็จแล้ว
    final riderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: widget.uid)
        .where('currentStatus', isEqualTo: 'delivered')
        .snapshots();

    // รวม 2 Streams เข้าด้วยกัน
    final mergedStream = StreamGroup.merge([customerStream, riderStream]);

    return StreamBuilder<QuerySnapshot>(
      stream: mergedStream,
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

        // ใช้ Map เพื่อกรองรายการที่ซ้ำซ้อน (ถ้ามี)
        final uniqueDocs = {for (var doc in snapshot.data!.docs) doc.id: doc};
        final orderDocs = uniqueDocs.values.toList();

        // เรียงตามวันที่สร้างล่าสุด
        orderDocs.sort((a, b) {
          final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: orderDocs.length,
          itemBuilder: (context, index) {
            final doc = orderDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            // ส่งข้อมูลทั้งหมดไปให้ Widget ใหม่จัดการ
            return HistoryListItem(
              orderData: data,
              orderId: doc.id,
              onTap: () {
                setState(() {
                  _selectedOrderId = doc.id;
                });
              },
            );
          },
        );
      },
    );
  }

  /// Widget สำหรับแสดง "หน้ารายละเอียดประวัติ"
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

        if (riderId == null || riderId.isEmpty) {
          return _buildContent(orderData, null);
        }

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

  Widget _buildContent(
      Map<String, dynamic> orderData, Map<String, dynamic>? riderData) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData, riderData),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

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

  Widget _buildRiderInfoSection(Map<String, dynamic> riderData) {
    final riderName = riderData['fullname'] ?? 'ไม่มีข้อมูล';
    final riderPhone = riderData['phone'] ?? '-';
    final vehicleNo = riderData['vehicle_no'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ข้อมูลผู้จัดส่ง (ไรเดอร์)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('ชื่อ: $riderName'),
        Text('เบอร์โทร: $riderPhone'),
        Text('ทะเบียนรถ: $vehicleNo'),
      ],
    );
  }

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

/// Widget ใหม่สำหรับแสดงผลแต่ละรายการใน List อย่างมีประสิทธิภาพ
class HistoryListItem extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  final VoidCallback onTap;

  const HistoryListItem({
    super.key,
    required this.orderData,
    required this.orderId,
    required this.onTap,
  });

  @override
  State<HistoryListItem> createState() => _HistoryListItemState();
}

class _HistoryListItemState extends State<HistoryListItem> {
  String _riderName = 'กำลังโหลด...';

  @override
  void initState() {
    super.initState();
    _fetchRiderName();
  }

  /// ฟังก์ชันสำหรับดึงชื่อไรเดอร์แค่ครั้งเดียว
  Future<void> _fetchRiderName() async {
    final riderId = widget.orderData['riderId'] as String?;
    if (riderId == null || riderId.isEmpty) {
      if (mounted) setState(() => _riderName = 'ไม่มีข้อมูล');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(riderId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _riderName = doc.data()?['fullname'] ?? 'ไม่มีชื่อ';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _riderName = 'ผิดพลาด');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryAddress =
        widget.orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final timestamp = (widget.orderData['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy', 'th').format(timestamp)
        : '';
    final receiverName = deliveryAddress['receiverName'] ?? 'ไม่มีชื่อผู้รับ';

    return InkWell(
      onTap: widget.onTap,
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
                    'จัดส่งโดย: $_riderName', // <-- แสดงชื่อไรเดอร์
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'วันที่: $formattedDate',
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
}
