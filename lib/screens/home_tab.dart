import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  final bool isLoggedIn; 
  final VoidCallback? onNavigateToAI;

  const HomeTab({super.key, this.isLoggedIn = true, this.onNavigateToAI});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  
  String _fetchedUserName = 'Loading...';
  String _fetchedLocation = 'Loading...'; 
  bool _hasProfileData = false;

  // Live telemetry values from physical sensors
  double? _liveTemp;
  double? _liveHumidity;
  int? _liveLight;
  int? _liveMoisture;
  double? _livePh;
  bool _isLoadingTelemetry = true; 

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserProfile();
      _setupSensorStream();
    }
  }

  void _setupSensorStream() {
    debugPrint("--- STARTING SENSOR FETCH ---");
    // 1. Initial fetch of the most recent reading
    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .select()
        .order('created_at', ascending: false) 
        .limit(1)
        .maybeSingle()
        .then((data) {
      debugPrint("--- SENSOR DATA RECEIVED: $data ---");
      if (mounted && data != null) {
        setState(() {
          _liveTemp = (data['temperature'] != null) ? (data['temperature'] as num).toDouble() : null;
          _liveHumidity = (data['humidity'] != null) ? (data['humidity'] as num).toDouble() : null;
          _liveLight = (data['light'] != null) ? (data['light'] as num).toInt() : null;
          _liveMoisture = (data['soil_moisture'] != null) ? (data['soil_moisture'] as num).toInt() : null;
          _livePh = (data['ph_value'] != null) ? (data['ph_value'] as num).toDouble() : null;
          _isLoadingTelemetry = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingTelemetry = false);
      }
    }).catchError((e) {
      debugPrint('❌ Error fetching latest sensor reading: $e');
      if (mounted) setState(() => _isLoadingTelemetry = false);
    });

    // 2. Realtime listener
    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> records) {
      debugPrint("--- REALTIME SENSOR UPDATE: $records ---");
      if (mounted && records.isNotEmpty) {
        final latest = records.first;
        setState(() {
          _liveTemp = (latest['temperature'] != null) ? (latest['temperature'] as num).toDouble() : null;
          _liveHumidity = (latest['humidity'] != null) ? (latest['humidity'] as num).toDouble() : null;
          _liveLight = (latest['light'] != null) ? (latest['light'] as num).toInt() : null;
          _liveMoisture = (latest['soil_moisture'] != null) ? (latest['soil_moisture'] as num).toInt() : null;
          _livePh = (latest['ph_value'] != null) ? (latest['ph_value'] as num).toDouble() : null;
          _isLoadingTelemetry = false;
        });
      }
    }, onError: (err) {
      debugPrint("❌ Realtime stream error: $err");
    });
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, city, state, country') 
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (data != null && data['username'] != null && data['username'].toString().trim().isNotEmpty) {
            _fetchedUserName = data['username']; 
            _hasProfileData = true; 
            
            if (data['city'] != null) {
              _fetchedLocation = data['city'];
            } else if (data['state'] != null) {
              _fetchedLocation = data['state'];
            } else if (data['country'] != null) {
              _fetchedLocation = data['country'];
            } else {
              _fetchedLocation = 'Location not set';
            }
          } else {
            _fetchedUserName = user.email!.split('@')[0];
            _hasProfileData = false; 
            _fetchedLocation = 'Location not set';
          }
        });
      }
    } catch (error) {
      debugPrint('Error fetching name/location: $error');
      if (mounted) {
        setState(() {
          _fetchedUserName = Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'User';
          _hasProfileData = false;
          _fetchedLocation = 'Location not set';
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A single boolean determines if the app should show real data or standby/offline data
    final bool isActive = widget.isLoggedIn && _hasProfileData;

    return Container(
      color: const Color(0xFFEDF7F0),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true, 
        thickness: 6.0,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          controller: _scrollController, 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingAndWeatherWidget(),
                const SizedBox(height: 16),
                _buildActiveZoneIndicator(isActive), // ⭐ Replaced dropdown
                const SizedBox(height: 24),
                const Text('OVERALL HEALTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF064E3B), letterSpacing: 1.2)),
                const SizedBox(height: 8),
                _buildHealthWidget(isActive),
                const SizedBox(height: 24),
                _buildLiveTelemetryWidget(isActive),
                const SizedBox(height: 32), 
                _buildActiveAlertsWidget(isActive),
                const SizedBox(height: 32),
                _buildNextActionsWidget(isActive),
                const SizedBox(height: 24),
                _buildAIPredictionWidget(isActive),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildGreetingAndWeatherWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255), 
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color.fromARGB(255, 255, 219, 219), width: 3), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Hi, ', 
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF333333)), 
              children: [
                TextSpan(text: widget.isLoggedIn ? _fetchedUserName : 'Guest', style: TextStyle(color: _hasProfileData ? Colors.green : Colors.grey.shade500)), 
                const TextSpan(text: '!'), 
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isLoggedIn 
              ? (_hasProfileData ? 'Your ecosystem is flourishing today.' : 'Please complete your profile in Settings to connect.') 
              : 'System offline. Please log in to connect.',
            style: TextStyle(fontSize: 14, color: const Color(0xFF333333).withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          if (widget.isLoggedIn) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _hasProfileData ? const Color(0xFFAED9F1) : Colors.grey.shade200, 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wednesday, April 1, 2026', style: TextStyle(color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(
                            _hasProfileData ? _fetchedLocation : 'Location not set', 
                            style: TextStyle(
                              color: _hasProfileData ? const Color(0xFF222222) : Colors.grey.shade600, 
                              fontSize: 16, 
                              fontWeight: FontWeight.w800,
                              fontStyle: _hasProfileData ? FontStyle.normal : FontStyle.italic,
                            )
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Row(children: [
                            Icon(Icons.wb_sunny, color: _hasProfileData ? Colors.orange : Colors.grey.shade400, size: 28), 
                            Icon(Icons.cloud, color: _hasProfileData ? Colors.white : Colors.grey.shade300, size: 28)
                          ]),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_hasProfileData ? '32°C' : '--°C', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _hasProfileData ? const Color(0xFF222222) : Colors.grey.shade600, height: 1.1)),
                              Text(_hasProfileData ? 'Partly Cloudy' : '--', style: TextStyle(color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withOpacity(0.4), thickness: 1.5), 
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildWeatherDetail(Icons.air, _hasProfileData ? '12 km/h' : '--'),
                      _buildWeatherDetail(Icons.water_drop_outlined, _hasProfileData ? '68%' : '--'),
                      _buildWeatherDetail(Icons.umbrella_outlined, _hasProfileData ? '10% rain' : '--'),
                    ],
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: _hasProfileData ? Colors.green.shade700 : Colors.grey.shade500, size: 16),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _hasProfileData ? const Color(0xFF333333) : Colors.grey.shade600)),
      ],
    );
  }

  // ⭐ Replaced dropdown with a static status card
  Widget _buildActiveZoneIndicator(bool isActive) {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(Icons.local_florist, color: isActive ? const Color(0xFF064E3B) : Colors.grey.shade500, size: 22),
          const SizedBox(width: 12),
          Text(
            isActive ? 'Smart Planter (Active)' : 'System Standby', 
            style: TextStyle(color: isActive ? const Color(0xFF064E3B) : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14)
          ), 
          const Spacer(),
          CircleAvatar(radius: 4, backgroundColor: isActive ? Colors.greenAccent.shade700 : Colors.grey.shade400)
        ],
      ),
    );
  }

  Widget _buildHealthWidget(bool isActive) {
    Color mainBgColor = isActive ? const Color(0xFFA1E6A1) : Colors.grey.shade200; 
    Color darkGreen = isActive ? const Color(0xFF064E3B) : Colors.grey.shade700;
    Color progressFillColor = isActive ? const Color.fromARGB(255, 62, 154, 109) : Colors.grey.shade500; 
    Color progressTrackColor = isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade300; 

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: mainBgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HEALTH INDEX', style: TextStyle(color: darkGreen.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(isActive ? 'Excellent' : 'Standby', style: TextStyle(color: darkGreen, fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(isActive ? 'Optimal growth detected' : 'No active crop assigned', style: TextStyle(color: darkGreen, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 70, 
                    width: 70,
                    child: CircularProgressIndicator(
                      value: isActive ? 0.94 : 0.0, 
                      backgroundColor: progressTrackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(progressFillColor),
                      strokeWidth: 8, 
                    ),
                  ),
                  Text(isActive ? '94%' : '0%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: darkGreen)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryWidget(bool isActive) {
    // Loading spinner if active but still fetching
    if (isActive && _isLoadingTelemetry) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF006947)),
            SizedBox(height: 14),
            Text(
              'Connecting to sensors...',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    String getMoistStatus(int? moist) {
      if (moist == null) return 'idle';
      if (moist < 30) return 'danger';
      if (moist < 60) return 'warning';
      return 'optimal';
    }

    String getTempStatus(double? temp) {
      if (temp == null) return 'idle';
      if (temp > 32 || temp < 15) return 'danger';
      if (temp > 28 || temp < 18) return 'warning';
      return 'optimal';
    }

    String getHumidStatus(double? humid) {
      if (humid == null) return 'idle';
      if (humid > 85 || humid < 30) return 'warning';
      return 'optimal';
    }

    List<Widget> telemetryPills;

    if (isActive) {
      telemetryPills = [
        _buildTelemetryPill(
          'MOIST',
          _liveMoisture != null ? '$_liveMoisture%' : '--',
          Icons.water_drop,
          getMoistStatus(_liveMoisture),
        ),
        const SizedBox(width: 10),
        _buildTelemetryPill(
          'LUX',
          _liveLight != null ? '${_liveLight!}' : '--',
          Icons.light_mode,
          'optimal',
        ),
        const SizedBox(width: 10),
        _buildTelemetryPill(
          'TEMP',
          _liveTemp != null ? '${_liveTemp!.toStringAsFixed(1)}°' : '--',
          Icons.thermostat,
          getTempStatus(_liveTemp),
        ),
        const SizedBox(width: 10),
        _buildTelemetryPill(
          'PH',
          _livePh != null ? _livePh!.toStringAsFixed(1) : '--',
          Icons.science,
          'optimal',
        ),
        const SizedBox(width: 10),
        _buildTelemetryPill(
          'HUMID',
          _liveHumidity != null ? '${_liveHumidity!.toStringAsFixed(0)}%' : '--',
          Icons.air,
          getHumidStatus(_liveHumidity),
        ),
      ];
    } else {
      telemetryPills = [
        _buildTelemetryPill('MOIST', '--', Icons.water_drop, 'idle'),
        const SizedBox(width: 10),
        _buildTelemetryPill('LUX', '--', Icons.light_mode, 'idle'),
        const SizedBox(width: 10),
        _buildTelemetryPill('TEMP', '--', Icons.thermostat, 'idle'),
        const SizedBox(width: 10),
        _buildTelemetryPill('PH', '--', Icons.science, 'idle'),
        const SizedBox(width: 10),
        _buildTelemetryPill('HUMID', '--', Icons.air, 'idle'),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'LIVE TELEMETRY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: telemetryPills,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF48BB78), 'Optimal'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFED8936), 'Warning'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFF56565), 'Danger'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTelemetryPill(String label, String value, IconData icon, String status) {
    Color bgColor;

    if (status == 'optimal') {
      bgColor = const Color(0xFF48BB78); 
    } else if (status == 'warning') {
      bgColor = const Color(0xFFED8936); 
    } else if (status == 'danger') {
      bgColor = const Color(0xFFF56565); 
    } else {
      bgColor = Colors.grey.shade400; 
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95), 
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: bgColor, size: 20), 
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)), 
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)), 
        ],
      ),
    );
  }

  Widget _buildActiveAlertsWidget(bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            InkWell(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => NotificationsScreen(isLoggedIn: widget.isLoggedIn))
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('VIEW MORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (isActive) ...[
          _buildNewAlertRow(Icons.water_drop, Colors.blue.shade500, 'Humidity exceeds 85%', 'Smart Planter', '5m ago'),
          const SizedBox(height: 12),
          _buildNewAlertRow(Icons.lightbulb, Colors.amber.shade600, 'Grow lights active', 'Supplemental lighting', '1h ago'),
        ] else ...[
          _buildEmptyStateRow(Icons.notifications_paused, 'No active alerts.'),
        ]
      ],
    );
  }

  Widget _buildNextActionsWidget(bool isActive) {
    return Column( 
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Next Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            InkWell(
              onTap: () {
                if (widget.onNavigateToAI != null) {
                  widget.onNavigateToAI!();
                }              
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('VIEW SCHEDULE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (isActive) ...[
          _buildNewActionRow(Icons.air, Colors.blue.shade100, Colors.blue.shade700, 'Gentle Ventilation', 'Scheduled exhaust cycle'),
          const SizedBox(height: 12),
          _buildNewActionRow(Icons.eco, Colors.green.shade100, Colors.green.shade800, 'Mist Propagation', 'Misting Cycle'),
        ] else ...[
          _buildEmptyStateRow(Icons.event_busy, 'No upcoming actions estimated.'),
        ]
      ],
    );
  }

  Widget _buildNewAlertRow(IconData icon, Color iconColor, String title, String subtitle, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildNewActionRow(IconData icon, Color bgColor, Color iconColor, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))], 
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: bgColor, child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 16),
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateRow(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAIPredictionWidget(bool isActive) {
    String aiMessage = isActive 
      ? 'Seedling roots established. True leaves expected in 5 days based on current humidity and lux exposure.' 
      : 'System offline. Please log in and configure your profile to view AI insights.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF022C22) : Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: isActive ? Colors.green.shade900 : Colors.grey.shade300)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: isActive ? Colors.greenAccent : Colors.grey.shade400, size: 16),
              const SizedBox(width: 8),
              Text('AI PREDICTION', style: TextStyle(color: isActive ? Colors.greenAccent.shade400 : Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aiMessage,
            style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('VIEW FULL ANALYSIS', style: TextStyle(color: isActive ? Colors.greenAccent.shade400 : Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: isActive ? Colors.greenAccent.shade400 : Colors.grey.shade400, size: 16),
            ],
          )
        ],
      ),
    );
  }
}