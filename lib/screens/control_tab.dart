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

  // Track Mode
  bool _automationActive = true;

  // Track Manual States
  bool _manualPumpOn = false;
  bool _manualFanOn = false;

  // Track Auto States
  bool _autoPumpOn = false;
  bool _autoFanOn = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkProfileStatus();
      _setupRealtimeStreams();
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

  void _setupRealtimeStreams() {
    // 1. Listen for Mode and Manual Overrides
    Supabase.instance.client
        .from('device_controls')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .listen((List<Map<String, dynamic>> records) {
      if (mounted && records.isNotEmpty) {
        setState(() {
          _automationActive = records.first['automation_active'] ?? true;
          _manualPumpOn = records.first['pump_manual_override'] ?? false;
          _manualFanOn = records.first['fan_manual_override'] ?? false;
        });
      }
    });

    // 2. Listen for Live Sensor Triggers
    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> records) {
      if (mounted && records.isNotEmpty) {
        setState(() {
          _autoPumpOn = (records.first['irrigation_need'] == 1);
          _autoFanOn = (records.first['ventilation_need'] == 1);
        });
      }
    });
  }

  // Switches system between AI Auto and Manual Override
  Future<void> _setAutomationMode(bool isActive) async {
    try {
      await Supabase.instance.client
          .from('device_controls')
          .update({'automation_active': isActive})
          .eq('id', 1);
    } catch (e) {
      debugPrint("Error setting mode: $e");
    }
  }

  // Sends the manual command and instantly pauses AI if it was running
  Future<void> _toggleDevice(String deviceColumn, bool turnOn) async {
    if (_automationActive) {
      _setAutomationMode(false); // Pause AI when user intervenes
    }
    try {
      await Supabase.instance.client
          .from('device_controls')
          .update({deviceColumn: turnOn})
          .eq('id', 1);
    } catch (e) {
      debugPrint("Error updating $deviceColumn: $e");
    }
  }

  Future<void> _emergencyStopAll() async {
    try {
      await Supabase.instance.client
          .from('device_controls')
          .update({
            'automation_active': false,
            'pump_manual_override': false, 
            'fan_manual_override': false
          })
          .eq('id', 1);
    } catch (e) {
      debugPrint("Error triggering kill switch: $e");
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
              if (_isActive) _buildAutomationBanner(),
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
          Text('SYSTEM CONTROLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isActive ? const Color(0xFF005A3C) : Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Hardware Interface', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ⭐ NEW: Banner that shows if AI is running or paused
  Widget _buildAutomationBanner() {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
      decoration: BoxDecoration(
        color: _automationActive ? Colors.white : const Color(0xFFFFF7ED),
        border: Border.all(color: _automationActive ? Colors.transparent : const Color(0xFFF6AD55), width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(_automationActive ? Icons.smart_toy : Icons.front_hand, color: _automationActive ? const Color(0xFF064E3B) : const Color(0xFFDD6B20), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_automationActive ? 'AI Automation Active' : 'Manual Control Active', style: TextStyle(color: _automationActive ? const Color(0xFF064E3B) : const Color(0xFFDD6B20), fontWeight: FontWeight.bold, fontSize: 14)), 
                Text(_automationActive ? 'Sensors control the hardware.' : 'AI paused. Hardware locked to switches.', style: TextStyle(color: _automationActive ? Colors.grey.shade600 : const Color(0xFFDD6B20), fontSize: 11)), 
              ],
            ),
          ),
          if (!_automationActive) 
            TextButton(
              onPressed: () => _setAutomationMode(true),
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFDD6B20), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text("RESUME AI", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Row(
      children: [
        Expanded(child: _buildControlCard('Water Pump', 'Submersible A1', Icons.water_drop, Colors.blue, Colors.blue.shade50, 190, _autoPumpOn, _manualPumpOn, (val) => _toggleDevice('pump_manual_override', val))),
        const SizedBox(width: 16),
        Expanded(child: _buildControlCard('Vent Fan', 'Main Exhaust', Icons.air, Colors.green, Colors.cyan.shade50, 190, _autoFanOn, _manualFanOn, (val) => _toggleDevice('fan_manual_override', val))),
      ],
    );
  }

  Widget _buildControlCard(String title, String sub, IconData icon, MaterialColor iconColor, Color bgColor, double height, bool autoState, bool manualState, Function(bool) onChanged) {
    // If automation is ON, display the live AI state. If OFF, display the forced manual switch state.
    bool displayState = _automationActive ? autoState : manualState;
    String statusText = _automationActive ? (autoState ? "AUTO: ON" : "AUTO: OFF") : (manualState ? "FORCED: ON" : "FORCED: OFF");
    Color statusColor = _automationActive ? (autoState ? const Color(0xFFED8936) : Colors.grey.shade400) : (manualState ? iconColor.shade700 : Colors.grey.shade500);

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _isActive && displayState ? bgColor : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _isActive && displayState ? iconColor.shade100 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _isActive && displayState ? iconColor.shade700 : Colors.grey.shade400)),
              Switch(value: _isActive ? displayState : false, onChanged: _isActive ? onChanged : null, activeThumbColor: const Color(0xFF006947)),
            ],
          ),
          const Spacer(),
          Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
          const SizedBox(height: 2),
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

  Widget _buildEmergencyStop() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _isActive ? const Color(0xFFF95630).withOpacity(0.1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(16), border: Border.all(color: _isActive ? const Color(0xFFF95630).withOpacity(0.3) : Colors.grey.shade300)),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _isActive ? const Color(0xFFB02500) : Colors.grey.shade400, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30)),
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
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isActive ? _emergencyStopAll : null, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB02500), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('KILL SWITCH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)))),
        ],
      ),
    );
  }
}