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
  final ScrollController _scrollController = ScrollController();
  bool _hasProfileData = false;
  
  // AI State Variables
  bool _isAnalyzing = false;
  
  // Mapped from ai_insights
  int _healthIndex = 100;
  String _predictedIssue = "Awaiting Random Forest inference...";
  String _recommendedAction = "Loading...";

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
        final url = Uri.parse('http://10.0.2.2:8000/api/predict');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'temperature': (sensorData['temperature'] as num).toDouble(),
            'humidity': (sensorData['humidity'] as num).toDouble(),
            'soil_moisture': (sensorData['soil_moisture'] as num).toInt(),
            'ph_value': (sensorData['ph_value'] as num).toDouble(),
          }),
        );
      }

      final aiData = await Supabase.instance.client.from('ai_insights').select().eq('id', 1).single();

      if (mounted) {
        setState(() {
          _healthIndex = aiData['health_index'] ?? 100;
          _predictedIssue = aiData['predicted_issue'] ?? "No anomalies detected.";
          _recommendedAction = aiData['recommended_action'] ?? "System running optimally.";
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint("AI Error: $e");
      if (mounted) {
        setState(() {
          _recommendedAction = "Inference Failed";
          _predictedIssue = "Check Python Server Connection";
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F6F7), 
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF006947),
          onRefresh: _runRandomForestInference,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopTitles(), 
                _buildHealthIndexCard(), 
                const SizedBox(height: 28), // Balanced section spacing
                _buildRecommendationsSection(),
                const SizedBox(height: 16), // Bottom buffer
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopTitles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'INTELLIGENCE STATUS', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isActive ? const Color(0xFF005A3C) : Colors.grey.shade500)
          ),
          const SizedBox(height: 6),
          Text(
            _isActive ? 'AI Advisory Active' : 'System Offline', 
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndexCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(
        color: _isActive ? const Color.fromARGB(255, 150, 198, 150) : Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Index', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Optimal chlorophyll production in $_healthIndex% of canopy.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_isActive ? '$_healthIndex' : '--', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade400, height: 1)),
              Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), child: Text('%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF006947) : Colors.grey.shade400))),
            ],
          )
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
            Text('AI Recommendations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
            Text('Scikit-Learn', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 16), 
        
        if (_isAnalyzing && _isActive)
          Container(
            height: 120,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF006947)),
                  SizedBox(height: 16),
                  Text("Running AI Inference...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              _buildRecCard(
                Icons.water_drop, 
                Colors.blue, 
                'Irrigation', 
                _predictedIssue.contains("Root") ? 'Warning' : 'Optimal', 
                _predictedIssue.contains("Root") ? _recommendedAction : 'Soil Moisture Stability', 
                _predictedIssue.contains("Root") ? _predictedIssue : 'Moisture levels are currently stable.'
              ),
              const SizedBox(height: 16), 
              _buildRecCard(
                Icons.air, 
                Colors.green, 
                'Ventilation', 
                _predictedIssue.contains("heat") ? 'Warning' : 'Optimal', 
                _predictedIssue.contains("heat") ? _recommendedAction : 'Climate Stable', 
                _predictedIssue.contains("heat") ? _predictedIssue : 'Atmospheric conditions are ideal.'
              ),
            ],
          )
      ],
    );
  }

  Widget _buildRecCard(IconData icon, MaterialColor color, String tagLabel, String tagVal, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _isActive ? color.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 22, color: _isActive ? color.shade700 : Colors.grey.shade400)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tagLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400)),
                  Text(_isActive ? tagVal : '--', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isActive ? (tagVal == 'Optimal' ? color.shade700 : Colors.orange.shade700) : Colors.grey)),
                ],
              )
            ],
          ),
          const SizedBox(height: 14), 
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _isActive ? const Color(0xFF2C2F30) : Colors.grey.shade500)),
          const SizedBox(height: 6), 
          Text(_isActive ? desc : 'Data unavailable.', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4)),
        ],
      ),
    );
  }
}