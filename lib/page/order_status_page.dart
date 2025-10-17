// file: lib/page/order_status_page.dart

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
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
  String? _selectedOrderId;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _selectedOrderId = widget.orderId;
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (isDetailPage) {
          setState(() {
            _selectedOrderId = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(isDetailPage ? 'ติดตามสถานะการจัดส่ง' : 'รายการส่งของ',
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
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildOrderListView() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildOrderList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ค้นหา Order ID, ชื่อ/เบอร์ ผู้รับ...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    final senderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: senderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('คุณยังไม่มีรายการส่งของ'));
        }

        final uniqueDocs = {for (var doc in snapshot.data!.docs) doc.id: doc};
        var allDocs = uniqueDocs.values.toList();

        if (_searchTerm.isNotEmpty) {
          String lowerCaseSearch = _searchTerm.toLowerCase();
          allDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final deliveryAddress =
                data['deliveryAddress'] as Map<String, dynamic>? ?? {};

            final orderId = doc.id.toLowerCase();
            final receiverName =
                (deliveryAddress['receiverName'] as String?)?.toLowerCase() ??
                    '';
            final receiverPhone =
                (deliveryAddress['receiverPhone'] as String?)?.toLowerCase() ??
                    '';

            return orderId.contains(lowerCaseSearch) ||
                receiverName.contains(lowerCaseSearch) ||
                receiverPhone.contains(lowerCaseSearch);
          }).toList();
        }

        if (allDocs.isEmpty) {
          return const Center(child: Text('ไม่พบรายการที่ค้นหา'));
        }

        allDocs.sort((a, b) {
          final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          itemCount: allDocs.length,
          itemBuilder: (context, index) {
            final doc = allDocs[index];
            return OrderListItem(
              orderData: doc.data() as Map<String, dynamic>,
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

        LatLng? riderPosition;
        if (orderData.containsKey('currentLocation') &&
            orderData['currentLocation'] is GeoPoint) {
          final geoPoint = orderData['currentLocation'] as GeoPoint;
          riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        if (riderId == null || riderId.isEmpty) {
          return _buildContent(orderData, null, riderPosition);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(riderId)
              .snapshots(),
          builder: (context, riderSnapshot) {
            final riderData =
                riderSnapshot.data?.data() as Map<String, dynamic>?;
            return _buildContent(orderData, riderData, riderPosition);
          },
        );
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> orderData,
      Map<String, dynamic>? riderData, LatLng? riderPosition) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData, riderData),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMapSection(
      Map<String, dynamic> orderData, LatLng? riderPosition) {
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final deliveryGps = deliveryAddress['gps'] as GeoPoint?;
    final LatLng? deliveryLatLng = deliveryGps != null
        ? LatLng(deliveryGps.latitude, deliveryGps.longitude)
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
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
            initialCenter:
                riderPosition ?? deliveryLatLng ?? const LatLng(16.24, 103.25),
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                if (riderPosition != null)
                  Marker(
                    point: riderPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.blue, size: 40),
                  ),
                if (deliveryLatLng != null)
                  Marker(
                    point: deliveryLatLng,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: 'จุดหมายปลายทาง',
                      child: Icon(Icons.flag, color: Colors.red, size: 40),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusHeader(
      Map<String, dynamic> orderData, Map<String, dynamic>? riderData) {
    final status = orderData['currentStatus'] ?? 'pending';
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
        const Text('ข้อมูลไรเดอร์',
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
        currentIndex: 0,
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

// --- ⭐️ เพิ่ม: Widget ใหม่สำหรับแสดงผลรายการออเดอร์ ---
class OrderListItem extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  final VoidCallback onTap;

  const OrderListItem({
    super.key,
    required this.orderData,
    required this.orderId,
    required this.onTap,
  });

  @override
  State<OrderListItem> createState() => _OrderListItemState();
}

class _OrderListItemState extends State<OrderListItem> {
  Map<String, dynamic>? _riderData;

  @override
  void initState() {
    super.initState();
    _fetchRiderData();
  }

  Future<void> _fetchRiderData() async {
    final riderId = widget.orderData['riderId'] as String?;
    if (riderId == null || riderId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(riderId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _riderData = doc.data();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;
    final deliveryAddress =
        data['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final status = data['currentStatus'] ?? 'N/A';

    return InkWell(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status)
                          .withOpacity(0.2), // <-- ⭐️ แก้ไข
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _translateStatus(status), // <-- ⭐️ แก้ไข
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status), // <-- ⭐️ แก้ไข
                      ),
                    ),
                  ),
                  Text(
                    'ID: ${widget.orderId}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildInfoRow(Icons.person_pin_circle_outlined, 'ผู้รับ',
                  deliveryAddress['receiverName'] ?? 'N/A'),
              _buildInfoRow(Icons.phone_outlined, 'เบอร์โทร',
                  deliveryAddress['receiverPhone'] ?? 'N/A'),
              const SizedBox(height: 8),
              if (_riderData != null) ...[
                _buildInfoRow(Icons.two_wheeler_outlined, 'Rider',
                    _riderData!['fullname'] ?? 'N/A'),
                _buildInfoRow(Icons.phone_android_outlined, 'เบอร์โทร Rider',
                    _riderData!['phone'] ?? 'N/A'),
                _buildInfoRow(Icons.badge_outlined, 'ทะเบียนรถ',
                    _riderData!['vehicle_no'] ?? 'N/A'),
              ] else if (data['riderId'] != null) ...[
                const Text('กำลังโหลดข้อมูลไรเดอร์...'),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// --- ⭐️ ย้ายฟังก์ชันมาไว้นอกคลาส ---
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
