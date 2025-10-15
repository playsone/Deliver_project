import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class EditProfilePage extends StatefulWidget {
  final String uid;
  final int role;
  const EditProfilePage({super.key, required this.uid, required this.role});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final db = FirebaseFirestore.instance;
  UserModel? _user;
  LatLng defaultLocation = const LatLng(16.245721, 103.231722);
  final MapController _mapController = MapController();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _gpsController = TextEditingController();
  final _gps2Controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  final _vehicleRegController = TextEditingController();

  late LatLng _currentMarkerPos;
  late String _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _currentMarkerPos = defaultLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFC70808),
        elevation: 0,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(50),
            bottomRight: Radius.circular(50),
          ),
        ),
      ),
      body: FutureBuilder<UserModel>(
        future: fetchUser(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 🔄 Loading State
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC70808)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("ไม่พบข้อมูลผู้ใช้"));
          }

          _user = snapshot.data!;
          _profileImageUrl = _user!.profile;
          _nameController.text = _user!.fullname;
          _phoneController.text = _user!.phone;
          // _addressController.text = _user!.defaultAddress;

          // ✅ Loaded Successfully
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildProfileSection(),
                _buildFormSection(),
                _buildMapSection(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Future<UserModel> fetchUser(String uid) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: '8RBMRHVI8wafkHwFMYyVfj5m6Px1')
        .get();

    // log(querySnapshot.docs.first.data().toString());
    if (querySnapshot.docs.isEmpty) {
      throw Exception('User not found');
    }

    final doc = querySnapshot.docs.first;
    return UserModel.fromFirestore(doc);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _currentMarkerPos = point;
      _gpsController.text =
          "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
    });

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addressLine =
            "${p.subThoroughfare ?? ''} ${p.thoroughfare ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
        _addressController.text = addressLine.trim();
      }
    } catch (e) {
      debugPrint("Reverse Geocoding Error: $e");
    }
  }

  // 🔍 ค้นหาพิกัดจากที่อยู่
  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _currentMarkerPos = newPos;
          _gpsController.text =
              "${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}";
        });
        _mapController.move(newPos, 15);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ค้นหาพิกัดไม่สำเร็จ: $e")),
      );
    }
  }

  Future<void> _geocodeAddress2() async {
    final address = _address2Controller.text.trim();
    if (address.isEmpty) return;

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _currentMarkerPos = newPos;
          _gps2Controller.text =
              "${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}";
        });
        _mapController.move(newPos, 15);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ค้นหาพิกัดไม่สำเร็จ: $e")),
      );
    }
  }

  // 💾 ปุ่มบันทึกข้อมูล
  Future<void> _saveProfile() async {
    try {
      await db.collection('users').doc(widget.uid).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'gps': _gpsController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("บันทึกข้อมูลสำเร็จ!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    }
  }

  // 🧍 รูปโปรไฟล์
  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: _profileImageUrl.isNotEmpty
            ? NetworkImage(_profileImageUrl)
            : const NetworkImage('https://via.placeholder.com/150'),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // 📋 แบบฟอร์มแก้ไขข้อมูล
  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.role == 0) ...[
            _buildTextFieldWithLabel('ชื่อ-สกุล', _nameController),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('หมายเลขโทรศัพท์', _phoneController),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('รหัสผ่าน', _passwordController),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('รหัสผ่านอีกครั้ง', _password2Controller),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel(
                'ที่อยู่หรือสถานที่พิกัด', _addressController,
                suffixIcon: Icons.search, onIconTap: _geocodeAddress),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('พิกัด GPS (Lat, Lng)', _gpsController,
                isReadOnly: true),
            const SizedBox(height: 30),
            _buildTextFieldWithLabel(
                'ที่อยู่หรือสถานที่พิกัด2', _address2Controller,
                suffixIcon: Icons.search, onIconTap: _geocodeAddress2),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('พิกัด GPS (Lat, Lng)', _gps2Controller,
                isReadOnly: true),
            const SizedBox(height: 30),
          ] else if (widget.role == 1) ...[
            _buildTextFieldWithLabel('ชื่อ-สกุล', _nameController),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('หมายเลขโทรศัพท์', _phoneController),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel(
                'ที่อยู่หรือสถานที่พิกัด', _addressController,
                suffixIcon: Icons.search, onIconTap: _geocodeAddress),
            const SizedBox(height: 20),
            _buildTextFieldWithLabel('พิกัด GPS (Lat, Lng)', _gpsController,
                isReadOnly: true),
            const SizedBox(height: 30),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC70808),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'บันทึกข้อมูล',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🗺️ แผนที่
  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC70808), width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMarkerPos,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _currentMarkerPos,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFC70808),
                    size: 40,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithLabel(
      String label, TextEditingController controller,
      {IconData? suffixIcon,
      VoidCallback? onIconTap,
      bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon, color: const Color(0xFFC70808)),
                    onPressed: onIconTap,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home, label: 'หน้าแรก', isSelected: false),
          _NavItem(
              icon: Icons.history,
              label: 'ประวัติการส่งสินค้า',
              isSelected: false),
          _NavItem(icon: Icons.logout, label: 'ออกจากระบบ', isSelected: true),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  const _NavItem(
      {required this.icon, required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: isSelected ? Colors.white : Colors.white54),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12)),
      ],
    );
  }
}
