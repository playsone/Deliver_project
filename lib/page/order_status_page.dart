// file: lib/page/order_status_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/send_package_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class OrderStatusPage extends StatefulWidget {
  final String? orderId;
  final String uid;
  final int role;

  const OrderStatusPage({
    super.key,
    this.orderId,
    required this.uid,
    required this.role,
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final MapController _mapController = MapController();

  // --- ตัวแปร State สำหรับเก็บ ID ของออเดอร์ที่เลือก ---
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    // กำหนดค่าเริ่มต้นให้ State จาก widget ที่ส่งเข้ามา
    _selectedOrderId = widget.orderId;
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ State `_selectedOrderId` ในการตัดสินใจว่าเป็นหน้ารายละเอียดหรือไม่
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(isDetailPage ? 'ติดตามสถานะการจัดส่ง' : 'รายการส่งของ',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        // สร้างปุ่ม Back เองเมื่อเป็นหน้ารายละเอียด
        leading: isDetailPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // เมื่อกด Back ให้เคลียร์ State เพื่อกลับไปหน้ารายการ
                  setState(() {
                    _selectedOrderId = null;
                  });
                },
              )
            : null,
        // ปิดการสร้างปุ่ม Back อัตโนมัติเพื่อป้องกันการทำงานซ้ำซ้อน
        automaticallyImplyLeading: false,
      ),
      body: isDetailPage
          ? _buildOrderDetailView(_selectedOrderId!)
          : _buildOrderListView(),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ===================================================================
  // == WIDGETS สำหรับแสดง "หน้ารายการออเดอร์" ==
  // ===================================================================

  Widget _buildOrderListView() {
    return Column(
      children: [
        _buildActionCard(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'รายการทั้งหมด', // แก้ไขหัวข้อ
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(child: _buildOrderList()),
      ],
    );
  }

  Widget _buildActionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5)
        ],
      ),
      child: Column(
        children: [
          const Text('ต้องการส่งของใช่ไหม?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => Get.to(
                () => SendPackagePage(uid: widget.uid, role: widget.role)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            ),
            child: const Text('กดที่นี่เพื่อส่งของ'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('คุณยังไม่มีรายการส่งของ'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
            final formattedDate = timestamp != null
                ? DateFormat('dd MMM yy', 'th').format(timestamp)
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined,
                    color: _primaryColor),
                title: Text(data['orderDetails'] ?? 'ไม่มีรายละเอียด',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    'วันที่: $formattedDate - สถานะ: ${_translateStatus(data['currentStatus'])}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // --- แก้ไข: อัปเดต State เมื่อกดที่รายการ ---
                  setState(() {
                    _selectedOrderId = doc.id;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  // ===================================================================
  // == WIDGETS สำหรับแสดง "หน้ารายละเอียดออเดอร์" ==
  // ===================================================================

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

        // **แก้ไข:** ดึงตำแหน่งไรเดอร์จาก order document โดยตรง
        LatLng? riderPosition;
        if (orderData.containsKey('currentLocation') &&
            orderData['currentLocation'] is GeoPoint) {
          final geoPoint = orderData['currentLocation'] as GeoPoint;
          riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        // ไม่ต้อง fetch ข้อมูล user ของไรเดอร์อีกต่อไป เพราะตำแหน่งอยู่ใน order แล้ว
        return _buildContent(orderData, riderPosition);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> orderData, LatLng? riderPosition) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMapSection(
      Map<String, dynamic> orderData, LatLng? riderPosition) {
    final GeoPoint destPoint = orderData['deliveryAddress']['gps'] ??
        const GeoPoint(16.4746, 102.8247);
    final LatLng destinationLatLng =
        LatLng(destPoint.latitude, destPoint.longitude);
    final markers = <Marker>[
      Marker(
        point: destinationLatLng,
        child: const Icon(Icons.location_on, color: _primaryColor, size: 40),
      ),
    ];
    if (riderPosition != null) {
      markers.add(Marker(
        point: riderPosition,
        child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 40),
      ));
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: riderPosition ?? destinationLatLng,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0'),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusHeader(Map<String, dynamic> orderData) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails = orderData['orderDetails'] ?? 'ไม่มีรายละเอียด';
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final receiverName = deliveryAddress['recipientName'] ?? 'ไม่มีข้อมูล';
    final receiverPhone = deliveryAddress['recipientPhone'] ?? '-';

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
              Text('สถานะปัจจุบัน: ',
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
          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
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
        final history = statusHistory[index];
        final status = history['status'] as String;
        final timestamp = (history['timestamp'] as Timestamp?)?.toDate();
        final formattedTime = timestamp != null
            ? DateFormat('dd MMM yyyy, HH:mm', 'th').format(timestamp)
            : 'ไม่มีข้อมูลเวลา';
        bool isFirst = index == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Column(
                children: [
                  Icon(
                    isFirst
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    color: isFirst ? _primaryColor : Colors.grey,
                    size: 20,
                  ),
                  if (index != statusHistory.length - 1)
                    Container(height: 40, width: 2, color: Colors.grey.shade300)
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
                  ],
                ),
              ),
            ],
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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 5)
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
              icon: Icon(Icons.history), label: 'ประวัติการส่ง'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        currentIndex: 0, // ควรตั้งค่าให้ถูกต้องตามหน้าที่เลือก
        onTap: (index) {
          if (index == 0) {
            Get.offAll(() => HomeScreen(uid: widget.uid, role: widget.role));
          } else if (index == 1) {
            Get.to(() => HistoryPage(uid: widget.uid, role: widget.role));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}
