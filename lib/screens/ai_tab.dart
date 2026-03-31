import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AITab extends StatefulWidget {
  final bool isLoggedIn;
  const AITab({super.key, this.isLoggedIn = true});

  @override
  State<AITab> createState() => _AITabState();
}

class _AITabState extends State<AITab> {
  final ScrollController _scrollController = ScrollController();
  bool _hasProfileData = false;
  
  // Returns true only if logged in AND profile is configured
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
      debugPrint("AITab error: $e");
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
              _buildHeroCard(), 
              const SizedBox(height: 32),
              _buildRecommendationsSection(),
              const SizedBox(height: 32),
              _buildBentoAnalysisSection(),
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
            'INTELLIGENCE STATUS', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isActive ? const Color(0xFF005A3C) : Colors.grey.shade500)
          ),
          const SizedBox(height: 8),
          Text(
            _isActive ? 'AI Optimization Active' : 'System Offline', 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isActive ? const Color(0xFF69F6B8) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isActive ? 'Your greenhouse ecosystem is being balanced in real-time. Efficiency is up 18% today.' : 'Please log in and configure your profile to activate AI.', 
                  style: TextStyle(color: _isActive ? const Color(0xFF005A3C).withOpacity(0.9) : Colors.grey.shade600, fontSize: 14, height: 1.4)
                ),
                const SizedBox(height: 16),
                if (_isActive) 
                  Wrap(
                    spacing: 8, 
                    runSpacing: 8, 
                    children: [
                      _buildPill(Icons.thermostat, 'Optimized'),
                      _buildPill(Icons.bolt, 'Eco Mode'),
                    ],
                  )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.psychology, 
            size: 70, 
            color: _isActive ? const Color(0xFF006947).withOpacity(0.3) : Colors.grey.shade400
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF005A3C)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A3C), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Recommendations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
                Text('Based on local climate and sensor data', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            if (_isActive) const Text('View History', style: TextStyle(color: Color(0xFF006947), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildRecCard(Icons.water_drop, Colors.blue, 'Status', 'Scheduled', 'Targeted Hydration', 'Soil moisture in Zone B is at 34%. Recommendation: 500ml mist at 4:00 PM.', 'Auto-Watering', true),
            // ⭐ REMOVED the Grow Lights recommendation card
            const SizedBox(height: 16),
            _buildRecCard(Icons.air, Colors.green, 'CO2 Level', 'Optimal', 'Air Circulation', 'Humidity buildup detected in the north corner. Recommendation: Cycle intake fans.', 'Ventilation Sync', false),
          ],
        )
      ],
    );
  }

  Widget _buildRecCard(IconData icon, MaterialColor color, String tagLabel, String tagVal, String title, String desc, String switchLabel, bool switchVal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _isActive ? color.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _isActive ? color.shade700 : Colors.grey.shade400)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tagLabel.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400)),
                  Text(_isActive ? tagVal : '--', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isActive ? color.shade700 : Colors.grey)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(_isActive ? desc : 'Data unavailable.', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(switchLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              Switch(value: _isActive ? switchVal : false, onChanged: _isActive ? (val) {} : null, activeColor: const Color(0xFF006947)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBentoAnalysisSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isActive ? const Color.fromARGB(255, 150, 198, 150) : Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Index', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Visual analysis shows optimal chlorophyll production in 94% of canopy.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_isActive ? '94' : '--', style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade400, height: 1)),
              Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text('%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade400))),
            ],
          )
        ],
      ),
    );
  }
}