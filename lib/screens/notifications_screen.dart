import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isLoggedIn; // ⭐ Added login tracking
  const NotificationsScreen({super.key, this.isLoggedIn = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedZone = 'All Zones'; 
  final List<String> _zones = [
    'Zone A: Seeding Chamber',  
    'Zone B: Harvest Ready Bay', 
    'Zone C: Idle', 
    'All Zones'
  ];

  bool _hasProfileData = false;
  bool get _isActive => widget.isLoggedIn && _hasProfileData;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkProfileStatus();
    }
  }

  Future<void> _checkProfileStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client.from('profiles').select('username').eq('id', user.id).maybeSingle();
      if (mounted) {
        setState(() {
          _hasProfileData = data != null && data['username'] != null && data['username'].toString().trim().isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Notifications error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF006947)),
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF022C22), fontWeight: FontWeight.w900)),
      ),
      body: _isActive 
          ? _buildActiveState() 
          : _buildOfflineState(), // ⭐ Shows the offline message if not active
    );
  }

  // ⭐ NEW: The Offline / Unconfigured UI
  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              !widget.isLoggedIn ? Icons.notifications_off : Icons.person_off, 
              size: 80, 
              color: Colors.grey.shade400
            ),
            const SizedBox(height: 24),
            Text(
              !widget.isLoggedIn ? 'System Offline' : 'Profile Incomplete',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              !widget.isLoggedIn 
                  ? 'Please log in to view your system alerts and notifications.' 
                  : 'Please complete your profile in Settings to connect your ecosystem.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // The Active UI
  Widget _buildActiveState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stay updated with your botanical ecosystem.', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          
          _buildZoneDropdown(),
          const SizedBox(height: 24),

          ..._buildDynamicNotifications(),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              children: [
                Text('OLDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey)),
                Expanded(child: Divider(indent: 16)),
              ],
            ),
          ),
          
          Opacity(
            opacity: 0.5,
            child: _buildNotifCard(Icons.lock, Colors.grey, 'Security', 'OCT 24', 'Credentials Updated', 'Two-factor authentication has been successfully enabled.'),
          )
        ],
      ),
    );
  }

  Widget _buildZoneDropdown() {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, 
          value: _selectedZone,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600), 
          items: _zones.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(color: Color(0xFF022C22), fontWeight: FontWeight.bold, fontSize: 14)), 
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() { _selectedZone = newValue; });
            }
          }, 
        ),
      ),
    );
  }

  List<Widget> _buildDynamicNotifications() {
    List<Widget> notifications = [];

    if (_selectedZone.contains('Zone A') || _selectedZone == 'All Zones') {
      notifications.addAll([
        _buildNotifCard(Icons.warning_amber_rounded, Colors.red, 'Critical', '2 MIN AGO', '(Zone A) Extreme Moisture Drop', 'Tray 4 has dropped below 15%. Immediate irrigation required to prevent root stress.'),
        const SizedBox(height: 12),
        _buildNotifCard(Icons.thermostat, Colors.orange, 'Warning', '1 HOUR AGO', '(Zone A) High Temperature', 'Greenhouse A is reaching 29°C. Consider activating supplementary ventilation.'),
        const SizedBox(height: 12),
      ]);
    }

    if (_selectedZone.contains('Zone B') || _selectedZone == 'All Zones') {
      notifications.addAll([
        _buildNotifCard(Icons.cloud_off, Colors.red, 'Critical', '15 MIN AGO', '(Zone B) CO2 Depletion', 'Atmospheric CO2 fell below 400ppm during peak photosynthesis phase.'),
        const SizedBox(height: 12),
        _buildNotifCard(Icons.eco, Colors.green, 'Ready', '2 HOURS AGO', '(Zone B) Peak Ripeness', 'Visual AI and sensors indicate optimal sugar brix levels. Ready for harvest.'),
        const SizedBox(height: 12),
      ]);
    }

    if (_selectedZone.contains('Zone C') || _selectedZone == 'All Zones') {
      notifications.addAll([
        _buildNotifCard(Icons.notifications_paused, Colors.grey, 'Status', '1 DAY AGO', '(Zone C) Idle State', 'Zone C is currently inactive. Actuators powered down to save energy.'),
        const SizedBox(height: 12),
      ]);
    }

    if (_selectedZone == 'All Zones') {
      notifications.addAll([
        _buildNotifCard(Icons.system_update_alt, Colors.blue, 'Update', '4 HOURS AGO', 'AI Optimization v2.4', 'Improved predictive watering algorithm for tropical species applied to all zones.'),
        const SizedBox(height: 12),
      ]);
    }

    return notifications;
  }

  Widget _buildNotifCard(IconData icon, MaterialColor color, String tag, String time, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle), child: Icon(icon, color: color.shade700)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tag.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: color.shade700)),
                    Text(time, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C2F30))),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}