import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlsTab extends StatefulWidget {
  final bool isLoggedIn;
  const ControlsTab({super.key, this.isLoggedIn = true});

  @override
  State<ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<ControlsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _hasProfileData = false;
  bool get _isActive => widget.isLoggedIn && _hasProfileData;

  // Toggle States
  bool _pumpOn = false;
  bool _fanOn = false;

  // ⭐ NEW: Zone Dropdown State
  String _selectedZone = 'Zone A: Seeding Chamber'; 
  final List<String> _zones = [
    'Zone A: Seeding Chamber',  
    'Zone B: Harvest Ready Bay', 
    'Zone C: Idle', 
    'All Zones'
  ];

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
      debugPrint("ControlsTab error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6F7),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopTitles(),
              _buildZoneDropdown(), // ⭐ Added the zone dropdown
              const SizedBox(height: 24),
              _buildGrid(),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildEmergencyStop(), 
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopTitles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'SYSTEM CONTROLS', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isActive ? const Color(0xFF005A3C) : Colors.grey.shade500)
          ),
          const SizedBox(height: 8),
          Text(
            'Manual Override',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _isActive ? 'Direct hardware control interface. AI automation is currently active, manual changes will pause auto-optimization.' : 'System offline. Login required to access manual controls.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ⭐ NEW: Zone Dropdown Widget
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
          onChanged: _isActive ? (String? newValue) {
            if (newValue != null) {
              setState(() { _selectedZone = newValue; });
            }
          } : null, 
        ),
      ),
    );
  }

  Widget _buildEmergencyStop() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isActive ? const Color(0xFFF95630).withOpacity(0.1) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isActive ? const Color(0xFFF95630).withOpacity(0.3) : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12), 
                decoration: BoxDecoration(color: _isActive ? const Color(0xFFB02500) : Colors.grey.shade400, shape: BoxShape.circle), 
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30)
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Stop All', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF520C00) : Colors.grey.shade600)),
                    Text('Instantly cut power to all actuators', style: TextStyle(fontSize: 12, color: _isActive ? const Color(0xFF520C00).withOpacity(0.8) : Colors.grey.shade500)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isActive ? () {} : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB02500), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('KILL SWITCH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Row(
      children: [
        // ⭐ UPDATED: Passed specific height and distinct light blue/cyan colors
        Expanded(child: _buildControlCard('Water Pump', 'Submersible A1', Icons.water_drop, Colors.blue, Colors.blue.shade50, 180, _pumpOn, (v) => setState(() => _pumpOn = v))),
        const SizedBox(width: 16),
        Expanded(child: _buildControlCard('Vent Fan', 'Main Exhaust', Icons.air, Colors.green, Colors.cyan.shade50, 180, _fanOn, (v) => setState(() => _fanOn = v))),
      ],
    );
  }

  // ⭐ UPDATED: Added height and bgColor parameters, and a Spacer to push text to the bottom
  Widget _buildControlCard(String title, String sub, IconData icon, MaterialColor iconColor, Color bgColor, double height, bool val, Function(bool) onChanged) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isActive ? bgColor : Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _isActive ? iconColor.shade100 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _isActive ? iconColor.shade700 : Colors.grey.shade400)),
              Switch(value: _isActive ? val : false, onChanged: _isActive ? onChanged : null, activeColor: const Color(0xFF006947)),
            ],
          ),
          const Spacer(), // ⭐ Pushes the text down so the card feels tall and substantial
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(sub.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatMicroCard('Power Draw', _isActive ? '1.24 kW/h' : '--', true)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatMicroCard('Uptime', _isActive ? '14d 2h' : '--', false)),
      ],
    );
  }

  Widget _buildStatMicroCard(String title, String val, bool isPulse) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: _isActive ? (isPulse ? Colors.greenAccent.shade700 : Colors.green) : Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
              Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade400)),
            ],
          )
        ],
      ),
    );
  }
}