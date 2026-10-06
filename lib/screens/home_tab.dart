import 'dart:io';
import 'dart:convert';
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

  // Real-time Weather Data
  String _weatherTemp = '--°C';
  String _weatherDesc = '--';
  String _weatherWind = '-- km/h';
  String _weatherHumid = '--%';
  String _weatherRain = '-- mm';
  IconData _weatherIcon = Icons.cloud;
  Color _weatherIconColor = Colors.grey.shade400;
  String _ecosystemSubtitle = 'Your ecosystem is flourishing today.';

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserProfile();
      _setupSensorStream();
    }
  }

  // Generates today's formatted date
  String _getTodayDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // Fetches real weather and dynamically updates weather greeting
  Future<void> _fetchWeather(String location) async {
    try {
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1&language=en&format=json');
      final geoReq = await HttpClient().getUrl(geoUrl);
      final geoRes = await geoReq.close();
      final geoBody = await geoRes.transform(utf8.decoder).join();
      final geoData = jsonDecode(geoBody);
      
      if (geoData['results'] == null || geoData['results'].isEmpty) return;
      
      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      
      final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m');
      final weatherReq = await HttpClient().getUrl(weatherUrl);
      final weatherRes = await weatherReq.close();
      final weatherBody = await weatherRes.transform(utf8.decoder).join();
      final weatherData = jsonDecode(weatherBody);
      
      final current = weatherData['current'];
      final code = current['weather_code'] as int;
      final temp = (current['temperature_2m'] as num).toDouble();
      
      String desc = 'Clear';
      IconData icon = Icons.wb_sunny;
      Color color = Colors.orange;
      String subtitle = 'Your ecosystem is flourishing today.';
      
      if (code <= 1) { 
        desc = 'Clear'; 
        icon = Icons.wb_sunny; 
        color = Colors.orange; 
        subtitle = 'Clear skies today. Optimal light exposure for your plants.';
      } else if (code <= 3) { 
        desc = 'Partly Cloudy'; 
        icon = Icons.cloud; 
        color = const Color(0xFF64B5F6); 
        subtitle = 'Gentle cloud cover today. Balanced diffuse light for growth.';
      } else if (code <= 48) { 
        desc = 'Foggy'; 
        icon = Icons.foggy; 
        color = Colors.grey.shade400; 
        subtitle = 'Misty conditions outdoors. Humidity balance is on watch.';
      } else if (code <= 67) { 
        desc = 'Rain'; 
        icon = Icons.water_drop; 
        color = Colors.blue.shade400; 
        subtitle = 'Rainfall outside. Internal microclimate remains protected.';
      } else if (code <= 77) { 
        desc = 'Snow'; 
        icon = Icons.ac_unit; 
        color = Colors.lightBlue; 
        subtitle = 'Chilly weather outside. Root warmth is fully maintained.';
      } else { 
        desc = 'Storm'; 
        icon = Icons.thunderstorm; 
        color = Colors.deepPurpleAccent; 
        subtitle = 'Stormy conditions outside. Automated defenses standing guard.';
      }

      // Heat check override
      if (temp >= 33.0) {
        subtitle = 'High ambient heat today. Active ventilation is standing by.';
      }

      if (mounted) {
        setState(() {
          _weatherTemp = '${temp.round()}°C';
          _weatherDesc = desc;
          _weatherWind = '${current['wind_speed_10m'].round()} km/h';
          _weatherHumid = '${current['relative_humidity_2m']}%';
          _weatherRain = '${current['precipitation']} mm';
          _weatherIcon = icon;
          _weatherIconColor = color;
          _ecosystemSubtitle = subtitle;
        });
      }
    } catch (e) {
      debugPrint('Weather API Error: $e');
    }
  }

  void _setupSensorStream() {
    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .select()
        .order('created_at', ascending: false) 
        .limit(1)
        .maybeSingle()
        .then((data) {
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
      if (mounted) setState(() => _isLoadingTelemetry = false);
    });

    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> records) {
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
              _fetchedLocation = 'Shah Alam'; 
            }
            
            _fetchWeather(_fetchedLocation);
          } else {
            _fetchedUserName = user.email!.split('@')[0];
            _hasProfileData = false; 
            _fetchedLocation = 'Shah Alam';
            _fetchWeather(_fetchedLocation);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _fetchedUserName = Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'User';
          _hasProfileData = false;
          _fetchedLocation = 'Shah Alam';
          _fetchWeather(_fetchedLocation);
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingAndWeatherWidget(),
                const SizedBox(height: 16),
                const Text('OVERALL HEALTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF064E3B), letterSpacing: 1.2)),
                const SizedBox(height: 5),
                _buildHealthWidget(isActive),
                const SizedBox(height: 18),
                _buildLiveTelemetryWidget(isActive),
                const SizedBox(height: 20), 
                _buildActiveAlertsWidget(isActive),
                const SizedBox(height: 20),
                _buildNextActionsWidget(isActive),
                const SizedBox(height: 20),
                _buildAIPredictionWidget(isActive),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingAndWeatherWidget() {
    return Container(
      padding: const EdgeInsets.all(16), 
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
              ? (_hasProfileData ? _ecosystemSubtitle : 'Please complete your profile in Settings to connect.') 
              : 'System offline. Please log in to connect.',
            style: TextStyle(fontSize: 14, color: const Color(0xFF333333).withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          if (widget.isLoggedIn) ...[
            const SizedBox(height: 12), 
            Container(
              padding: const EdgeInsets.all(16), 
              decoration: BoxDecoration(
                color: _hasProfileData ? const Color(0xFFAED9F1) : Colors.grey.shade200, 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Date & Location takes all available extra space
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTodayDate().toUpperCase(), 
                              style: TextStyle(color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fetchedLocation, 
                              style: TextStyle(
                                color: _hasProfileData ? const Color(0xFF222222) : Colors.grey.shade600, 
                                fontSize: 16, 
                                fontWeight: FontWeight.w800,
                                fontStyle: _hasProfileData ? FontStyle.normal : FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Right: Weather Icon grouped closely with Temperature
                      Row(
                        children: [
                          Icon(
                            _weatherIcon, 
                            color: _hasProfileData ? _weatherIconColor : Colors.grey.shade400, 
                            size: 40,
                          ),
                          const SizedBox(width: 35), // Controls the gap between the icon and temperature
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_hasProfileData ? _weatherTemp : '--°C', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _hasProfileData ? const Color(0xFF222222) : Colors.grey.shade600, height: 1.1)),
                              Text(_hasProfileData ? _weatherDesc : '--', style: TextStyle(color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.end),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 4), // Reduced top gap above divider
                  Divider(color: Colors.white.withOpacity(0.4), thickness: 1.5), 
                  const SizedBox(height: 4), // Reduced bottom gap below divider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildWeatherDetail(Icons.air, _hasProfileData ? _weatherWind : '--'),
                      _buildWeatherDetail(Icons.water_drop_outlined, _hasProfileData ? _weatherHumid : '--'),
                      _buildWeatherDetail(Icons.umbrella_outlined, _hasProfileData ? _weatherRain : '--'),
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
        Icon(icon, color: _hasProfileData ? Colors.green.shade700 : Colors.grey.shade500, size: 19),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _hasProfileData ? const Color(0xFF333333) : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildHealthWidget(bool isActive) {
    Color mainBgColor = isActive ? const Color(0xFFA1E6A1) : Colors.grey.shade200; 
    Color darkGreen = isActive ? const Color(0xFF064E3B) : Colors.grey.shade700;
    Color progressFillColor = isActive ? const Color.fromARGB(255, 62, 154, 109) : Colors.grey.shade500; 
    Color progressTrackColor = isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade300; 

    return Container(
      padding: const EdgeInsets.all(16), 
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

    // Target: ~80%
    String getMoistStatus(int? moist) {
      if (moist == null) return 'idle';
      if (moist < 50 || moist > 95) return 'danger'; // Too dry OR waterlogged
      if (moist < 70 || moist > 90) return 'warning'; // Slightly off-target
      return 'optimal'; // 70% to 90% is optimal
    }

    // Target: 22°C - 28°C
    String getTempStatus(double? temp) {
      if (temp == null) return 'idle';
      if (temp < 18 || temp > 32) return 'danger';
      if (temp < 22 || temp > 28) return 'warning';
      return 'optimal';
    }

    // Target: ~80%
    String getHumidStatus(double? humid) {
      if (humid == null) return 'idle';
      if (humid < 60 || humid > 95) return 'danger';
      if (humid < 70 || humid > 90) return 'warning';
      return 'optimal';
    }

    // Target: ~6.5
    String getPhStatus(double? ph) {
      if (ph == null) return 'idle';
      if (ph < 5.0 || ph > 8.0) return 'danger';
      if (ph < 5.8 || ph > 7.2) return 'warning';
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
        const SizedBox(width: 8),
        _buildTelemetryPill(
          'LUX',
          _liveLight != null ? '${_liveLight!}' : '--',
          Icons.light_mode,
          'optimal', // Locked to always stay green
        ),
        const SizedBox(width: 8),
        _buildTelemetryPill(
          'TEMP',
          _liveTemp != null ? '${_liveTemp!.toStringAsFixed(1)}°' : '--',
          Icons.thermostat,
          getTempStatus(_liveTemp),
        ),
        const SizedBox(width: 8),
        _buildTelemetryPill(
          'PH',
          _livePh != null ? _livePh!.toStringAsFixed(1) : '--',
          Icons.science,
          getPhStatus(_livePh), 
        ),
        const SizedBox(width: 8),
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
        const SizedBox(width: 8),
        _buildTelemetryPill('LUX', '--', Icons.light_mode, 'idle'),
        const SizedBox(width: 8),
        _buildTelemetryPill('TEMP', '--', Icons.thermostat, 'idle'),
        const SizedBox(width: 8),
        _buildTelemetryPill('PH', '--', Icons.science, 'idle'),
        const SizedBox(width: 8),
        _buildTelemetryPill('HUMID', '--', Icons.air, 'idle'),
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), 
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: telemetryPills,
            ),
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10), 
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
          const SizedBox(height: 8), 
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)), 
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)), 
        ],
      ),
    );
  }

Widget _buildActiveAlertsWidget(bool isActive) {
    List<Widget> alertRows = [];

    // Dynamically generate alerts based on live sensor data
    if (isActive && !_isLoadingTelemetry) {
      if (_liveHumidity != null && _liveHumidity! > 90) {
        alertRows.add(_buildNewAlertRow(Icons.water_drop, Colors.blue.shade500, 'Humidity exceeds 90%', 'Smart Planter', 'Just now'));
        alertRows.add(const SizedBox(height: 12));
      }
      if (_liveTemp != null && _liveTemp! > 28) {
        alertRows.add(_buildNewAlertRow(Icons.thermostat, Colors.orange.shade600, 'Temperature high (${_liveTemp!.toStringAsFixed(1)}°C)', 'Climate Control', 'Just now'));
        alertRows.add(const SizedBox(height: 12));
      }
      if (_liveMoisture != null && (_liveMoisture! < 70 || _liveMoisture! > 95)) {
        String msg = _liveMoisture! < 70 ? 'Soil moisture low' : 'Soil waterlogged';
        alertRows.add(_buildNewAlertRow(Icons.eco, Colors.brown.shade500, '$msg (${_liveMoisture}%)', 'Root Zone', 'Just now'));
        alertRows.add(const SizedBox(height: 12));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(isLoggedIn: widget.isLoggedIn)));
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('VIEW MORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        if (isActive && alertRows.isNotEmpty) 
          ...alertRows
        else if (isActive && alertRows.isEmpty)
          _buildEmptyStateRow(Icons.check_circle_outline, 'All parameters optimal.')
        else 
          _buildEmptyStateRow(Icons.notifications_paused, 'No active alerts.')
      ],
    );
  }

  Widget _buildNextActionsWidget(bool isActive) {
    List<Widget> actionRows = [];

    // Dynamically prescribe actions based on live sensor data
    if (isActive && !_isLoadingTelemetry) {
      if (_liveTemp != null && _liveTemp! > 28) {
        actionRows.add(_buildNewActionRow(Icons.air, Colors.blue.shade100, Colors.blue.shade700, 'Active Exhaust', 'Cooling cycle triggered by high temp'));
        actionRows.add(const SizedBox(height: 12));
      } else if (_liveHumidity != null && _liveHumidity! > 90) {
        actionRows.add(_buildNewActionRow(Icons.air, Colors.blue.shade100, Colors.blue.shade700, 'Gentle Ventilation', 'Scheduled exhaust cycle for humidity'));
        actionRows.add(const SizedBox(height: 12));
      }
      
      if (_liveMoisture != null && _liveMoisture! < 70) {
        actionRows.add(_buildNewActionRow(Icons.water_drop, Colors.green.shade100, Colors.green.shade800, 'Irrigation Burst', 'Watering cycle required'));
        actionRows.add(const SizedBox(height: 12));
      }
    }

    return Column( 
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Next Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            InkWell(
              onTap: () {
                if (widget.onNavigateToAI != null) widget.onNavigateToAI!();
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('VIEW SCHEDULE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        if (isActive && actionRows.isNotEmpty) 
          ...actionRows
        else if (isActive && actionRows.isEmpty)
          _buildEmptyStateRow(Icons.eco_outlined, 'No immediate actions required.')
        else 
          _buildEmptyStateRow(Icons.event_busy, 'No upcoming actions estimated.')
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