import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AITab extends StatefulWidget {
  final bool isLoggedIn;
  const AITab({super.key, this.isLoggedIn = true});

  @override
  State<AITab> createState() => _AITabState();
}

class _AITabState extends State<AITab> {
  bool _hasProfileData = false;
  bool _isAnalyzing = false;
  int _healthIndex = 100;
  
  double _currentTemp = 25.0;
  double _currentHum = 60.0;
  int _currentSoil = 50;

  bool get _isActive => widget.isLoggedIn && _hasProfileData;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkProfileStatus().then((_) {
        if (_isActive) _runRandomForestInference();
      });
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

  Future<void> _runRandomForestInference() async {
    setState(() => _isAnalyzing = true);

    try {
      final sensorData = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select('temperature, humidity, soil_moisture, ph_value')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (sensorData != null) {
        _currentTemp = (sensorData['temperature'] as num).toDouble();
        _currentHum = (sensorData['humidity'] as num).toDouble();
        _currentSoil = (sensorData['soil_moisture'] as num).toInt();

        final url = Uri.parse('http://10.0.2.2:8000/api/predict');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'temperature': _currentTemp,
            'humidity': _currentHum,
            'soil_moisture': _currentSoil,
            'ph_value': (sensorData['ph_value'] as num).toDouble(),
          }),
        );
      }

      final aiData = await Supabase.instance.client.from('ai_insights').select().eq('id', 1).single();

      if (mounted) {
        setState(() {
          _healthIndex = aiData['health_index'] ?? 100;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint("AI Error: $e");
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6F7), 
      child: SafeArea(
        // LayoutBuilder dynamically measures the exact height of the phone screen
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              color: const Color(0xFF006947),
              onRefresh: _runRandomForestInference,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Keeps pull-to-refresh working
                child: ConstrainedBox(
                  // Forces the design to fill the whole screen, anchoring the empty space at the bottom
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16), 
                        _buildTopTitles(), 
                        const SizedBox(height: 20), 
                        _buildHealthIndexCard(), 
                        const SizedBox(height: 14), 
                        _buildRecommendationsSection(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildTopTitles() {
    return SizedBox(
      width: double.infinity, // Guarantees perfect centering across the screen
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'SYSTEM STATUS', 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isActive ? const Color(0xFF005A3C) : Colors.grey.shade500)
          ),
          const SizedBox(height: 6),
          Text(
            _isActive ? 'AI Helper is Active' : 'System Offline', 
            // Increased font size
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndexCard() {
    bool isPerfect = (_currentSoil <= 85 && _currentSoil >= 35) && 
                     (_currentTemp <= 32 && _currentTemp >= 20) && 
                     (_currentHum <= 80 && _currentHum >= 40);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18), // Reduced internal padding
      decoration: BoxDecoration(
        color: _isActive ? const Color.fromARGB(255, 150, 198, 150) : Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade500)), // Smaller title
          const SizedBox(height: 4), // Tighter gap
          Text(
            _isActive 
              ? (isPerfect ? 'Perfect environment for plant growth for now.' : 'Some conditions are lowering the plant health score.')
              : 'System is currently offline.', 
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800) // Smaller description text
          ),
          const SizedBox(height: 12), // Tighter gap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_isActive ? '$_healthIndex' : '--', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade400, height: 1.0)), // Reduced huge number
                  Padding(padding: const EdgeInsets.only(bottom: 6.0, left: 4.0), child: Text('%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade400))),
                ],
              ),
              if (_isActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _buildIssueChips(),
                  ),
                )
            ],
          )
        ],
      ),
    );
  }

  List<Widget> _buildIssueChips() {
    List<Widget> chips = [];

    if (_currentSoil > 85) chips.add(_buildChip('Soil is too wet', Colors.red));
    if (_currentSoil < 35) chips.add(_buildChip('Soil is too dry', Colors.orange));
    if (_currentTemp > 32) chips.add(_buildChip('Too hot', Colors.red));
    if (_currentTemp < 20) chips.add(_buildChip('Too cold', Colors.blue));
    if (_currentHum > 80) chips.add(_buildChip('Air is too damp', Colors.orange));
    if (_currentHum < 40) chips.add(_buildChip('Air is too dry', Colors.orange));

    if (chips.isEmpty) {
      chips.add(_buildChip('Perfect environment', Colors.green));
    }

    List<Widget> spacedChips = [];
    for (int i = 0; i < chips.length; i++) {
      spacedChips.add(chips[i]);
      if (i < chips.length - 1) {
        spacedChips.add(const SizedBox(height: 8));
      }
    }
    return spacedChips;
  }

  Widget _buildChip(String label, MaterialColor dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Icon(Icons.circle, size: 8, color: dotColor), // Slightly smaller dot
          const SizedBox(width: 6),
          Text(
            label, 
            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold, height: 1.1), // Adjusted text size
          ),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('AI Suggestions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)), // Increased header
            Text('Scikit-Learn', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 16), 
        
        if (_isAnalyzing && _isActive)
          Container(
            height: 100,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF006947)),
                  SizedBox(height: 12),
                  Text("Checking plants...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14))
                ],
              ),
            ),
          )
        else if (_isActive)
          Column(
            children: [
              _buildDynamicIrrigationCard(),
              const SizedBox(height: 16), 
              _buildDynamicVentilationCard(),
            ],
          )
      ],
    );
  }

  Widget _buildDynamicIrrigationCard() {
    String status, title, desc;
    MaterialColor color;
    
    if (_currentSoil > 85) {
      status = 'Warning';
      title = 'Soil is Too Wet';
      desc = 'The soil has too much water. Please stop watering so the roots do not get sick.';
      color = Colors.red;
    } else if (_currentSoil < 35) {
      status = 'Action Needed';
      title = 'Soil is Too Dry';
      desc = 'The plants are thirsty. Please turn on the water pump.';
      color = Colors.orange;
    } else {
      status = 'All Good';
      title = 'Perfect Moisture';
      desc = 'The soil has just the right amount of water for the sweet potatoes.';
      color = Colors.blue;
    }

    return _buildRecCard(Icons.water_drop, color, 'Watering', status, title, desc);
  }

  Widget _buildDynamicVentilationCard() {
    String status, title, desc;
    MaterialColor color;

    if (_currentTemp > 32) {
      status = 'Warning';
      title = 'Too Hot';
      desc = 'It is too hot for the plants. Keep the fans on to cool down the area.';
      color = Colors.red;
    } else if (_currentTemp < 20) {
      status = 'Action Needed';
      title = 'Too Cold';
      desc = 'It is getting chilly. Turn off the fans to keep the plants warm.';
      color = Colors.blue;
    } else if (_currentHum > 80) {
      status = 'Warning';
      title = 'Air is Too Damp';
      desc = 'The air is very wet and can make the leaves sick. Keep the fans on to clear the air.';
      color = Colors.orange;
    } else if (_currentHum < 40) {
      status = 'Action Needed';
      title = 'Air is Too Dry';
      desc = 'The air is very dry. Turn off the fans so the plants stay moist.';
      color = Colors.orange;
    } else {
      status = 'All Good';
      title = 'Great Weather';
      desc = 'The temperature and humidity are perfect right now.';
      color = Colors.green;
    }
    
    return _buildRecCard(Icons.air, color, 'Air & Temp', status, title, desc);
  }

  Widget _buildRecCard(IconData icon, MaterialColor color, String tagLabel, String tagVal, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: color.shade700)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tagLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400)),
                  Text(tagVal, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tagVal == 'All Good' ? color.shade700 : (tagVal == 'Warning' ? Colors.red.shade700 : Colors.orange.shade700))),
                ],
              )
            ],
          ),
          const SizedBox(height: 14), 
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2C2F30))), // Increased titles
          const SizedBox(height: 6), 
          Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4)), // Increased descriptions
        ],
      ),
    );
  }
}