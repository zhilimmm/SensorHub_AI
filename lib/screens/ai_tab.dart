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
  bool _hasTelemetryData = false;
  bool _isAnalyzing = false;

  int _healthIndex = 100;

  String _irrigationStatus = "All Good";
  String _irrigationTitle = "Waiting for AI";
  String _irrigationDesc = "Fetching the latest insights...";

  String _ventilationStatus = "All Good";
  String _ventilationTitle = "Waiting for AI";
  String _ventilationDesc = "Fetching the latest insights...";

  bool get _isActive => widget.isLoggedIn && _hasProfileData;
  bool get _isAiReady => _isActive && _hasTelemetryData;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkProfileStatus().then((_) {
        if (_isActive) _runRandomForestInference();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AITab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && !oldWidget.isLoggedIn) {
      _checkProfileStatus().then((_) {
        if (_isActive) _runRandomForestInference();
      });
    } else if (!widget.isLoggedIn && oldWidget.isLoggedIn) {
      setState(() {
        _hasProfileData = false;
        _hasTelemetryData = false;
      });
    }
  }

  Future<void> _checkProfileStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _hasProfileData = data != null &&
              data['username'] != null &&
              data['username'].toString().trim().isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("AITab error: $e");
    }
  }

  Future<void> _runRandomForestInference() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Query telemetry isolated by the logged-in user's `user_id`
      final sensorData = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select('temperature, humidity, soil_moisture, ph_value')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (sensorData == null) {
        if (mounted) {
          setState(() {
            _hasTelemetryData = false;
            _isAnalyzing = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _hasTelemetryData = true);
      }

      // Trigger the Python FastAPI backend to run the Random Forest
      final url = Uri.parse('https://sensorhub-ai-backend.onrender.com/api/predict');
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

      final aiData = await Supabase.instance.client
          .from('ai_insights')
          .select()
          .eq('id', 1)
          .single();

      if (mounted) {
        setState(() {
          _healthIndex = aiData['health_index'] ?? 100;

          _irrigationStatus = aiData['irrigation_status'] ?? 'All Good';
          _irrigationTitle = aiData['irrigation_title'] ?? 'Perfect Moisture';
          _irrigationDesc = aiData['irrigation_desc'] ?? 'The soil has just the right amount of water.';

          _ventilationStatus = aiData['ventilation_status'] ?? 'All Good';
          _ventilationTitle = aiData['ventilation_title'] ?? 'Great Weather';
          _ventilationDesc = aiData['ventilation_desc'] ?? 'The temperature and humidity are perfect right now.';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              color: const Color(0xFF006947),
              onRefresh: _runRandomForestInference,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildTopTitles(),
                        const SizedBox(height: 12),
                        _buildHealthIndexCard(),
                        const SizedBox(height: 10),
                        _buildRecommendationsSection(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopTitles() {
    String statusHeading;
    if (!widget.isLoggedIn) {
      statusHeading = 'System Offline';
    } else if (!_hasProfileData) {
      statusHeading = 'Setup Required';
    } else if (!_hasTelemetryData) {
      statusHeading = 'AI Helper Standby';
    } else {
      statusHeading = 'AI Helper is Active';
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'SYSTEM STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: _isAiReady ? const Color(0xFF005A3C) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusHeading,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _isAiReady ? const Color(0xFF022C22) : Colors.grey.shade700,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndexCard() {
    bool isPerfect = (_irrigationStatus == 'All Good' && _ventilationStatus == 'All Good');

    String subtitleMessage;
    if (!widget.isLoggedIn) {
      subtitleMessage = 'System is currently offline.';
    } else if (!_hasProfileData) {
      subtitleMessage = 'Complete your profile in Settings to activate AI insights.';
    } else if (!_hasTelemetryData) {
      subtitleMessage = 'No sensor data in database for this account yet.';
    } else {
      subtitleMessage = isPerfect
          ? 'Perfect environment for plant growth for now.'
          : 'Some conditions are lowering the plant health score.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isAiReady ? const Color.fromARGB(255, 150, 198, 150) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isAiReady ? const Color(0xFF006947) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleMessage,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _isAiReady ? '$_healthIndex' : '--',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: _isAiReady ? const Color(0xFF2C2F30) : Colors.grey.shade400,
                      height: 1.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
                    child: Text(
                      '%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isAiReady ? const Color(0xFF006947) : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isAiReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: _buildIssueChips(),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildIssueChips() {
    final bool hasIrrIssue = _irrigationStatus != 'All Good';
    final bool hasVentIssue = _ventilationStatus != 'All Good';

    if (!hasIrrIssue && !hasVentIssue) {
      return _buildChip('Perfect environment', Colors.green);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasIrrIssue)
          _buildChip(_irrigationTitle, _irrigationStatus == 'Warning' ? Colors.red : Colors.orange),
        if (hasIrrIssue && hasVentIssue)
          const SizedBox(height: 8),
        if (hasVentIssue)
          _buildChip(_ventilationTitle, _ventilationStatus == 'Warning' ? Colors.red : Colors.orange),
      ],
    );
  }

  Widget _buildChip(String label, MaterialColor dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: dotColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold, height: 1.1)),
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
            Text(
              'AI Recommendations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _isAiReady ? const Color(0xFF2C2F30) : Colors.grey.shade500,
              ),
            ),
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
                  Text("Checking plants...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          )
        else if (_isAiReady)
          Column(
            children: [
              _buildDynamicIrrigationCard(),
              const SizedBox(height: 16),
              _buildDynamicVentilationCard(),
            ],
          )
        else if (_isActive && !_hasTelemetryData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.sensors_off, color: Colors.grey.shade400, size: 36),
                const SizedBox(height: 10),
                Text(
                  'No sensor data in database yet.\nConnect your ESP32 device to generate AI suggestions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicIrrigationCard() {
    MaterialColor color = _irrigationStatus == 'Warning' ? Colors.red : (_irrigationStatus == 'Action Needed' ? Colors.orange : Colors.blue);
    return _buildRecCard(Icons.water_drop, color, 'Watering', _irrigationStatus, _irrigationTitle, _irrigationDesc);
  }

  Widget _buildDynamicVentilationCard() {
    MaterialColor color = _ventilationStatus == 'Warning' ? Colors.red : (_ventilationStatus == 'Action Needed' ? Colors.orange : Colors.green);
    return _buildRecCard(Icons.air, color, 'Air & Temp', _ventilationStatus, _ventilationTitle, _ventilationDesc);
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 24, color: color.shade700),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tagLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey.shade400)),
                  Text(
                    tagVal,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tagVal == 'All Good'
                          ? color.shade700
                          : (tagVal == 'Warning' ? Colors.red.shade700 : Colors.orange.shade700),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C2F30))),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4)),
        ],
      ),
    );
  }
}