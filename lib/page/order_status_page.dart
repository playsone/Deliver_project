// order_status_page.dart

import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/package_pickup_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

// Constants (ประกาศซ้ำเพื่อความสะดวกในการแยกไฟล์)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);
const Color _accentColor = Color(0xFF0D47A1);

class OrderStatusPage extends StatefulWidget {
  final String? orderId;
  final String uid;
  final int role; // 0 = User (Sender/Recipient), 1 = Rider

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

  Map<String, dynamic>? _senderData;
  Map<String, dynamic>? _recipientData;
  Map<String, dynamic>? _riderData;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _selectedOrderId = widget.orderId;
    if (_selectedOrderId != null) {
      _initializeOrderData(_selectedOrderId!);
    }
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.trim();
      });
    });
  }

  @override
  void didUpdateWidget(covariant OrderStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderId != oldWidget.orderId) {
      _selectedOrderId = widget.orderId;
      if (_selectedOrderId != null) {
        _initializeOrderData(_selectedOrderId!);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ฟังก์ชันรวมสำหรับการโหลดข้อมูล (แก้ไขปัญหา setState during build)
  Future<void> _initializeOrderData(String orderId) async {
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    if (!orderDoc.exists) return;

    final orderData = orderDoc.data() as Map<String, dynamic>;
    final senderId = orderData['customerId'] as String;
    final riderId = orderData['riderId'] as String?;

    if (mounted) {
      setState(() {
        _senderData = null;
        _recipientData = null;
        _riderData = null;
      });
    }

    // A. ดึงข้อมูลผู้ส่ง
    await _fetchSenderData(senderId);

    // B. ตั้งค่าข้อมูลผู้รับ (จากข้อมูล Order)
    _setRecipientDataFromOrder(orderData);

    // C. ดึงข้อมูลไรเดอร์
    await _fetchRiderData(riderId);
  }

  // Helper สำหรับดึงข้อมูลผู้ส่ง
  Future<void> _fetchSenderData(String senderId) async {
    if (senderId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    if (mounted) {
      setState(() {
        _senderData = doc.data();
      });
    }
  }

  // Helper สำหรับตั้งค่าข้อมูลผู้รับ (จาก Order Data)
  void _setRecipientDataFromOrder(Map<String, dynamic> orderData) {
    if (mounted) {
      setState(() {
        _recipientData = {
          'fullname':
              orderData['deliveryAddress']?['receiverName'] ?? 'ไม่ระบุ',
          'phone': orderData['deliveryAddress']?['receiverPhone'] ?? '-',
        };
      });
    }
  }

  // Helper สำหรับดึงข้อมูลไรเดอร์
  Future<void> _fetchRiderData(String? riderId) async {
    if (riderId == null || riderId.isEmpty) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(riderId).get();
    if (mounted) {
      setState(() {
        _riderData = doc.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    String appBarTitle;
    if (isDetailPage) {
      final bool isCurrentUserSender = widget.role == 0 &&
          _senderData != null &&
          _senderData!['uid'] == widget.uid;

      if (isCurrentUserSender) {
        appBarTitle = 'ติดตามการส่งของ';
      } else if (widget.role == 0) {
        appBarTitle = 'ติดตามพัสดุรับเข้า';
      } else if (widget.role == 1) {
        appBarTitle = 'สถานะงานไรเดอร์';
      } else {
        appBarTitle = 'ติดตามสถานะ';
      }
    } else {
      appBarTitle = 'รายการส่งของที่คุณสร้าง';
    }

    return WillPopScope(
      onWillPop: () async {
        if (isDetailPage) {
          setState(() {
            _selectedOrderId = null;
            _senderData = null;
            _recipientData = null;
            _riderData = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
          backgroundColor: _primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: isDetailPage
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedOrderId = null;
                      _senderData = null;
                      _recipientData = null;
                      _riderData = null;
                    });

                    Get.to(() =>
                        PackagePickupPage(uid: widget.uid, role: widget.role));
                  },
                )
              : null,
          automaticallyImplyLeading: !isDetailPage,
        ),
        body: isDetailPage
            ? _buildOrderDetailView(_selectedOrderId!)
            : _buildOrderListView(), // แสดงรายการส่งของเมื่อไม่ใช่หน้า Detail
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
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

  Widget _buildOrderListView() {
    if (widget.role != 0) {
      return Center(
          child: Text('คุณไม่มีสิทธิ์เข้าถึงรายการส่งของ',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700)));
    }

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
          return Center(
              child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('คุณยังไม่มีรายการส่งของที่สร้างขึ้น'));
        }

        var allDocs = snapshot.data!.docs;

        // 1. Client-side Sorting (ล่าสุดก่อน)
        allDocs.sort((a, b) {
          final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        // 2. Client-side Filtering (ค้นหา)
        if (_searchTerm.isNotEmpty) {
          final lowerCaseSearch = _searchTerm.toLowerCase();
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

        if (allDocs.isEmpty && _searchTerm.isNotEmpty) {
          return Column(
            children: [
              _buildSearchBar(),
              const Expanded(child: Center(child: Text('ไม่พบรายการที่ค้นหา')))
            ],
          );
        }

        return Column(
          // ต้องใช้ Column เพื่อให้มีพื้นที่สำหรับ Search Bar
          children: [
            _buildSearchBar(), // <<< แถบ Search
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                itemCount: allDocs.length,
                itemBuilder: (context, index) {
                  final doc = allDocs[index];
                  return OrderListItem(
                    orderData: doc.data() as Map<String, dynamic>,
                    orderId: doc.id,
                    isSenderRole: true, // โหมดผู้ส่ง
                    onTap: () {
                      setState(() {
                        _selectedOrderId = doc.id;
                        _initializeOrderData(doc.id); // โหลดข้อมูลเมื่อกด
                      });
                    },
                  );
                },
              ),
            ),
          ],
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

        // ตรวจสอบความสมบูรณ์ของข้อมูลที่โหลดไว้ใน State
        final bool isCurrentUserSender = orderData['customerId'] == widget.uid;
        final bool isEssentialDataLoaded =
            (isCurrentUserSender && _recipientData != null) ||
                (!isCurrentUserSender && _senderData != null);

        if (!isEssentialDataLoaded) {
          return const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('กำลังโหลดข้อมูลผู้เกี่ยวข้อง...')
            ],
          ));
        }

        LatLng? riderPosition;
        if (orderData.containsKey('currentLocation') &&
            orderData['currentLocation'] is GeoPoint) {
          final geoPoint = orderData['currentLocation'] as GeoPoint;
          riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        // *** ✅ ตรรกะ Real-time Map Panning ***
        if (riderPosition != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(riderPosition!, 14.0); // ใช้ zoom คงที่ 14.0
          });
        }
        // *** --------------------------------- ***

        return _buildContent(orderData, riderPosition);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> orderData, LatLng? riderPosition) {
    final bool isCurrentUserSender = orderData['customerId'] == widget.uid;

    final Map<String, dynamic>? primaryUserInfo =
        isCurrentUserSender ? _recipientData : _senderData;
    final String primaryUserRoleTitle =
        isCurrentUserSender ? 'ผู้รับ' : 'ผู้ส่ง';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(
              orderData, primaryUserInfo, primaryUserRoleTitle),
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

    final pickupAddress =
        orderData['pickupAddress'] as Map<String, dynamic>? ?? {};
    final pickupGps = pickupAddress['gps'] as GeoPoint?;
    final LatLng? pickupLatLng = pickupGps != null
        ? LatLng(pickupGps.latitude, pickupGps.longitude)
        : null;

    final initialCenter = riderPosition ??
        deliveryLatLng ??
        pickupLatLng ??
        const LatLng(16.24, 103.25);

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
            initialCenter: initialCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              // ใช้ OpenStreetMap เพื่อหลีกเลี่ยง API Key Error
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',

              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                if (pickupLatLng != null)
                  Marker(
                    point: pickupLatLng,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: 'จุดรับพัสดุ',
                      child:
                          Icon(Icons.location_on, color: Colors.blue, size: 40),
                    ),
                  ),
                if (riderPosition != null)
                  Marker(
                    point: riderPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.purple, size: 40),
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

  Widget _buildCurrentStatusHeader(Map<String, dynamic> orderData,
      Map<String, dynamic>? primaryUserInfo, String primaryUserRoleTitle) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails =
        orderData['orderDetails'].toString().trim() ?? 'ไม่มีรายละเอียด';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderDetails,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
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

          // ข้อมูลผู้รับ/ผู้ส่ง ที่เราต้องการดู (ตามบทบาท)
          _buildRelatedUserInfoSection(primaryUserInfo, primaryUserRoleTitle),

          // ข้อมูลไรเดอร์
          if (orderData['riderId'] != null &&
              orderData['riderId'].isNotEmpty) ...[
            const Divider(height: 20),
            _buildRiderInfoSection(_riderData),
          ],

          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Widget แสดงข้อมูลผู้ส่งหรือผู้รับ
  Widget _buildRelatedUserInfoSection(
      Map<String, dynamic>? userData, String title) {
    final name = userData?['fullname'] ?? 'กำลังโหลด...';
    final phone = userData?['phone'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ข้อมูล$title',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('ชื่อ: $name'),
        Text('เบอร์โทร: $phone'),
      ],
    );
  }

  Widget _buildRiderInfoSection(Map<String, dynamic>? riderData) {
    final riderName = riderData?['fullname'] ?? 'กำลังโหลด...';
    final riderPhone = riderData?['phone'] ?? '-';
    final vehicleNo = riderData?['vehicle_no'] ?? '-';

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
    // Sort: Newest first
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
                        height: (imageUrl != null &&
                                imageUrl.isNotEmpty &&
                                imageUrl != 'received by recipient')
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
                    if (imageUrl != null &&
                        imageUrl.isNotEmpty &&
                        imageUrl != 'received by recipient')
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
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
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

// Helper functions (ใช้ร่วมกับ OrderStatusPage และ PackagePickupPage)
String _translateStatus(String status) {
  switch (status) {
    case 'pending':
      return 'รอไรเดอร์รับงาน';
    case 'assigned':
    case 'accepted':
      return 'ไรเดอร์รับงานแล้ว';
    case 'picked_up':
      return 'รับพัสดุแล้ว';
    case 'in_transit':
      return 'กำลังนำส่ง';
    case 'delivered':
      return 'จัดส่งสำเร็จ';
    case 'completed':
      return 'ผู้รับยืนยันแล้ว ✔️';
    default:
      return status;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.blueGrey;
    case 'assigned':
    case 'accepted':
      return Colors.orange;
    case 'picked_up':
    case 'in_transit':
      return Colors.amber.shade800;
    case 'delivered':
    case 'completed':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

class OrderListItem extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  final VoidCallback onTap;
  final bool isSenderRole;

  const OrderListItem({
    super.key,
    required this.orderData,
    required this.orderId,
    required this.onTap,
    this.isSenderRole = false,
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
    final pickupAddress = data['pickupAddress'] as Map<String, dynamic>? ?? {};
    final status = data['currentStatus'] ?? 'N/A';

    // Determine the main user info to show based on the list's purpose
    final String mainLabel = widget.isSenderRole ? 'ผู้รับ' : 'ผู้ส่ง';
    final String mainName = widget.isSenderRole
        ? deliveryAddress['receiverName'] ?? 'N/A'
        : pickupAddress['senderName'] ?? 'N/A';
    final String mainPhone = widget.isSenderRole
        ? deliveryAddress['receiverPhone'] ?? 'N/A'
        : pickupAddress['senderPhone'] ?? 'N/A';

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
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _translateStatus(status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  Text(
                    'ID: ${widget.orderId.substring(0, 8)}...',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const Divider(height: 16),

              // แสดงข้อมูลผู้รับ/ผู้ส่ง ตามบทบาท
              _buildInfoRow(
                  Icons.person_pin_circle_outlined, mainLabel, mainName),
              _buildInfoRow(
                  Icons.phone_outlined, 'เบอร์โทร$mainLabel', mainPhone),

              const SizedBox(height: 8),
              if (_riderData != null) ...[
                _buildInfoRow(Icons.two_wheeler_outlined, 'Rider',
                    _riderData!['fullname'] ?? 'N/A'),
                _buildInfoRow(Icons.phone_android_outlined, 'เบอร์โทร Rider',
                    _riderData!['phone'] ?? 'N/A'),
              ] else if (data['riderId'] != null &&
                  data['riderId'].isNotEmpty) ...[
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
