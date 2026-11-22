import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback? onNavigateToAI;

  const HomeTab({super.key, this.isLoggedIn = true, this.onNavigateToAI});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _sensorSubscription;
  StreamSubscription? _healthSubscription;

  String _fetchedUserName = 'Loading...';
  String _fetchedLocation = 'Loading...';
  bool _hasProfileData = false;

  // Active crop configuration from `public.user_plants`
  Map<String, dynamic>? _activePlant;
  bool _isLoadingPlant = true;

  // Synced Health Score & AI commentary from `public.ai_insights`
  int _healthIndex = 100;

  // Live telemetry values from physical sensors (filtered by user_id)
  double? _liveTemp;
  double? _liveHumidity;
  int? _liveLight;
  int? _liveMoisture;
  double? _livePh;
  bool _isLoadingTelemetry = true;

  bool get _hasTelemetryData =>
      _liveTemp != null ||
      _liveHumidity != null ||
      _liveLight != null ||
      _liveMoisture != null ||
      _livePh != null;

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
      refreshData();
    } else {
      _isLoadingTelemetry = false;
      _isLoadingPlant = false;
    }
  }

  /// Public method so `main.dart` can refresh HomeTab immediately when
  /// the user updates their profile or changes their plant in SettingsTab.
  Future<void> refreshData() async {
    if (!widget.isLoggedIn) return;
    await Future.wait([
      _fetchUserProfile(),
      _fetchUserPlant(),
    ]);
    _setupSensorStream();
    _setupHealthScoreStream();
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
      final encodedLocation = Uri.encodeComponent(location);
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encodedLocation&count=1&language=en&format=json');
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

  // Fetches the user's active plant from `public.user_plants`
  Future<void> _fetchUserPlant() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _activePlant = null;
            _isLoadingPlant = false;
          });
        }
        return;
      }

      final plantData = await Supabase.instance.client
          .from('user_plants')
          .select('plant_name, harvest_days, planted_date')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activePlant = plantData;
          _isLoadingPlant = false;
        });
      }
    } catch (e) {
      debugPrint('HomeTab User Plant Error: $e');
      if (mounted) {
        setState(() {
          _activePlant = null;
          _isLoadingPlant = false;
        });
      }
    }
  }

  // Fetches and listens to the AI Health Index & AI notes in real time
  void _setupHealthScoreStream() {
    _healthSubscription?.cancel();

    Supabase.instance.client
        .from('ai_insights')
        .select('health_index, growth_forecast')
        .eq('id', 1)
        .maybeSingle()
        .then((data) {
      if (mounted && data != null) {
        setState(() {
          _healthIndex = data['health_index'] ?? 100;
        });
      }
    }).catchError((e) {
      debugPrint('HomeTab Health Score Error: $e');
    });

    _healthSubscription = Supabase.instance.client
        .from('ai_insights')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .listen((records) {
      if (mounted && records.isNotEmpty) {
        setState(() {
          _healthIndex = records.first['health_index'] ?? 100;
        });
      }
    });
  }

  // Fetches and streams sensor telemetry isolated by the logged-in user's `user_id`
  void _setupSensorStream() {
    _sensorSubscription?.cancel();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTelemetry = false);
      return;
    }

    if (mounted) setState(() => _isLoadingTelemetry = true);

    Supabase.instance.client
        .from('sweet_potato_leave_data')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .then((data) {
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _liveTemp = data['temperature'] != null ? (data['temperature'] as num).toDouble() : null;
          _liveHumidity = data['humidity'] != null ? (data['humidity'] as num).toDouble() : null;
          _liveLight = data['light'] != null ? (data['light'] as num).toInt() : null;
          _liveMoisture = data['soil_moisture'] != null ? (data['soil_moisture'] as num).toInt() : null;
          _livePh = data['ph_value'] != null ? (data['ph_value'] as num).toDouble() : null;
          _isLoadingTelemetry = false;
        });
      } else {
        setState(() {
          _liveTemp = null;
          _liveHumidity = null;
          _liveLight = null;
          _liveMoisture = null;
          _livePh = null;
          _isLoadingTelemetry = false;
        });
      }
    }).catchError((e) {
      debugPrint('Telemetry fetch error: $e');
      if (mounted) {
        setState(() {
          _liveTemp = null;
          _liveHumidity = null;
          _liveLight = null;
          _liveMoisture = null;
          _livePh = null;
          _isLoadingTelemetry = false;
        });
      }
    });

    _sensorSubscription = Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('id', ascending: false)
        .limit(1)
        .listen((records) {
      if (!mounted) return;
      if (records.isNotEmpty) {
        final latest = records.first;
        setState(() {
          _liveTemp = latest['temperature'] != null ? (latest['temperature'] as num).toDouble() : null;
          _liveHumidity = latest['humidity'] != null ? (latest['humidity'] as num).toDouble() : null;
          _liveLight = latest['light'] != null ? (latest['light'] as num).toInt() : null;
          _liveMoisture = latest['soil_moisture'] != null ? (latest['soil_moisture'] as num).toInt() : null;
          _livePh = latest['ph_value'] != null ? (latest['ph_value'] as num).toDouble() : null;
          _isLoadingTelemetry = false;
        });
      } else {
        setState(() {
          _liveTemp = null;
          _liveHumidity = null;
          _liveLight = null;
          _liveMoisture = null;
          _livePh = null;
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
            _fetchedUserName = data['username'].toString().trim();
            _hasProfileData = true;

            if (data['city'] != null && data['city'].toString().trim().isNotEmpty) {
              _fetchedLocation = data['city'];
            } else if (data['state'] != null && data['state'].toString().trim().isNotEmpty) {
              _fetchedLocation = data['state'];
            } else if (data['country'] != null && data['country'].toString().trim().isNotEmpty) {
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

  // Returns dynamic label, message, and colors for all 5 health score scenarios
  Map<String, dynamic> _getHealthScenario(int score) {
    if (score >= 90) {
      return {
        'label': 'Excellent',
        'message': 'Perfect environment for plant growth right now.',
        'bgColor': const Color(0xFFA1E6A1),
        'primaryColor': const Color(0xFF064E3B),
        'progressColor': const Color.fromARGB(255, 62, 154, 109),
      };
    } else if (score >= 75) {
      return {
        'label': 'Good',
        'message': 'Some conditions are slightly lowering the health score.',
        'bgColor': const Color(0xFFC5E8B7),
        'primaryColor': const Color(0xFF1B5E20),
        'progressColor': const Color(0xFF2E7D32),
      };
    } else if (score >= 55) {
      return {
        'label': 'Fair',
        'message': 'A few conditions need attention. Check the AI tab.',
        'bgColor': const Color(0xFFFFE082),
        'primaryColor': const Color(0xFFE65100),
        'progressColor': const Color(0xFFEF6C00),
      };
    } else if (score >= 35) {
      return {
        'label': 'Poor',
        'message': 'Plants are stressed. Action is needed soon.',
        'bgColor': const Color(0xFFFFCC80),
        'primaryColor': const Color(0xFFBF360C),
        'progressColor': const Color(0xFFD84315),
      };
    } else {
      return {
        'label': 'Critical',
        'message': 'Dangerous conditions detected! Check controls now.',
        'bgColor': const Color(0xFFFFAB91),
        'primaryColor': const Color(0xFFB71C1C),
        'progressColor': const Color(0xFFC62828),
      };
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _healthSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isProfileActive = widget.isLoggedIn && _hasProfileData;
    final bool isTelemetryActive = isProfileActive && _hasTelemetryData;

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
                _buildHealthWidget(isProfileActive, isTelemetryActive),
                const SizedBox(height: 18),
                _buildLiveTelemetryWidget(isProfileActive, isTelemetryActive),
                const SizedBox(height: 20),
                _buildActiveAlertsWidget(isProfileActive, isTelemetryActive),
                const SizedBox(height: 20),
                _buildNextActionsWidget(isProfileActive, isTelemetryActive),
                const SizedBox(height: 20),
                _buildAIPredictionWidget(isProfileActive),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _hasProfileData ? const Color(0xFFD1FAE5) : const Color.fromARGB(255, 255, 219, 219),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Hi, ',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF333333)),
              children: [
                TextSpan(
                  text: widget.isLoggedIn ? _fetchedUserName : 'Guest',
                  style: TextStyle(color: _hasProfileData ? Colors.green : Colors.grey.shade500),
                ),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTodayDate().toUpperCase(),
                              style: TextStyle(
                                color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
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
                      Row(
                        children: [
                          Icon(
                            _weatherIcon,
                            color: _hasProfileData ? _weatherIconColor : Colors.grey.shade400,
                            size: 40,
                          ),
                          const SizedBox(width: 35),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _hasProfileData ? _weatherTemp : '--°C',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: _hasProfileData ? const Color(0xFF222222) : Colors.grey.shade600,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                _hasProfileData ? _weatherDesc : '--',
                                style: TextStyle(
                                  color: _hasProfileData ? const Color(0xFF666666) : Colors.grey.shade500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Divider(color: Colors.white.withOpacity(0.4), thickness: 1.5),
                  const SizedBox(height: 4),
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

  Widget _buildHealthWidget(bool isProfileActive, bool isTelemetryActive) {
    final scenario = _getHealthScenario(_healthIndex);

    final Color mainBgColor = isTelemetryActive ? scenario['bgColor'] : Colors.grey.shade200;
    final Color primaryTextColor = isTelemetryActive ? scenario['primaryColor'] : Colors.grey.shade700;
    final Color progressFillColor = isTelemetryActive ? scenario['progressColor'] : Colors.grey.shade500;
    final Color progressTrackColor = isTelemetryActive ? Colors.white.withOpacity(0.55) : Colors.grey.shade300;

    String standbySubtitle;
    if (!isProfileActive) {
      standbySubtitle = 'Complete your profile in Settings';
    } else if (_activePlant == null) {
      standbySubtitle = 'No active crop assigned';
    } else {
      standbySubtitle = 'No sensor data in database yet';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: mainBgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 82,
                width: 82,
                child: CircularProgressIndicator(
                  value: isTelemetryActive ? (_healthIndex / 100.0) : 0.0,
                  backgroundColor: progressTrackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressFillColor),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                isTelemetryActive ? '$_healthIndex%' : '0%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Health Index',
                  style: TextStyle(
                    color: primaryTextColor.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTelemetryActive ? scenario['label'] : 'Standby',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTelemetryActive ? scenario['message'] : standbySubtitle,
                  style: TextStyle(
                    color: primaryTextColor.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryWidget(bool isProfileActive, bool isTelemetryActive) {
    if (isProfileActive && _isLoadingTelemetry) {
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
      if (moist < 50 || moist > 95) return 'danger';
      if (moist < 70 || moist > 90) return 'warning';
      return 'optimal';
    }

    String getTempStatus(double? temp) {
      if (temp == null) return 'idle';
      if (temp < 18 || temp > 32) return 'danger';
      if (temp < 22 || temp > 28) return 'warning';
      return 'optimal';
    }

    String getHumidStatus(double? humid) {
      if (humid == null) return 'idle';
      if (humid < 60 || humid > 95) return 'danger';
      if (humid < 70 || humid > 90) return 'warning';
      return 'optimal';
    }

    String getPhStatus(double? ph) {
      if (ph == null) return 'idle';
      if (ph < 5.0 || ph > 8.0) return 'danger';
      if (ph < 5.8 || ph > 7.2) return 'warning';
      return 'optimal';
    }

    List<Widget> telemetryPills;

    if (isTelemetryActive) {
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
          'optimal',
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
          if (isProfileActive && !isTelemetryActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'No sensor data in database for this account yet.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
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
        boxShadow: [BoxShadow(color: bgColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
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

  Widget _buildActiveAlertsWidget(bool isProfileActive, bool isTelemetryActive) {
    List<Widget> alertRows = [];

    if (isTelemetryActive && !_isLoadingTelemetry) {
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
        if (isTelemetryActive && alertRows.isNotEmpty)
          ...alertRows
        else if (isTelemetryActive && alertRows.isEmpty)
          _buildEmptyStateRow(Icons.check_circle_outline, 'All parameters optimal.')
        else if (isProfileActive && !isTelemetryActive)
          _buildEmptyStateRow(Icons.sensors_off, 'No sensor data in database yet.')
        else
          _buildEmptyStateRow(Icons.notifications_paused, 'No active alerts.')
      ],
    );
  }

  Widget _buildNextActionsWidget(bool isProfileActive, bool isTelemetryActive) {
    List<Widget> actionRows = [];

    if (isTelemetryActive && !_isLoadingTelemetry) {
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
        if (isTelemetryActive && actionRows.isNotEmpty)
          ...actionRows
        else if (isTelemetryActive && actionRows.isEmpty)
          _buildEmptyStateRow(Icons.eco_outlined, 'No immediate actions required.')
        else if (isProfileActive && !isTelemetryActive)
          _buildEmptyStateRow(Icons.sensors_off, 'Connect ESP32 sensors to enable automation.')
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAIPredictionWidget(bool isProfileActive) {
    final bool hasPlant = isProfileActive && _activePlant != null;

    String dayBadge = '';
    String cropHeader = 'AI PREDICTION';
    String stageTitle = '';
    String harvestLine = '';
    String stageDescription = '';

    if (hasPlant) {
      final String plantName = (_activePlant!['plant_name'] as String?) ?? 'Sweet Potato Leaves';
      final int totalDays = (_activePlant!['harvest_days'] as int?) ?? 40;
      final DateTime plantedLocal = DateTime.parse(_activePlant!['planted_date']).toLocal();

      // Calculate exact calendar days elapsed from planting start date
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final plantedMidnight = DateTime(plantedLocal.year, plantedLocal.month, plantedLocal.day);

      final int currentDay = (todayMidnight.difference(plantedMidnight).inDays + 1).clamp(1, totalDays);
      final int daysLeft = (totalDays - currentDay).clamp(0, totalDays);
      final double progress = currentDay / totalDays;

      cropHeader = 'AI PREDICTION • ${plantName.toUpperCase()}';
      dayBadge = 'DAY $currentDay/$totalDays';

      if (progress <= 0.25) {
        stageTitle = 'Seedling & Root Establishment';
        stageDescription = 'Early root anchoring stage for $plantName. Maintain steady soil moisture and gentle airflow.';
      } else if (progress <= 0.65) {
        stageTitle = 'Vine & Canopy Expansion';
        stageDescription = 'Leaves are spreading actively. Optimal conditions are supporting strong vegetative growth.';
      } else if (daysLeft > 0) {
        stageTitle = 'Pre-Harvest Maturation';
        stageDescription = '$plantName foliage is approaching peak harvest size. Maintain balanced hydration.';
      } else {
        stageTitle = 'Ready for Harvest';
        stageDescription = '$plantName has reached its $totalDays-day target cycle and is ready for harvesting.';
      }

      harvestLine = daysLeft > 0
          ? 'Est. first leaf harvest in $daysLeft days'
          : 'Target harvest window reached today';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isProfileActive ? const Color(0xFF022C22) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isProfileActive ? Colors.green.shade900 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: isProfileActive ? Colors.greenAccent : Colors.grey.shade400,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cropHeader,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isProfileActive ? Colors.greenAccent.shade400 : Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPlant)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dayBadge,
                    style: TextStyle(
                      color: Colors.greenAccent.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isProfileActive)
            Text(
              'System offline. Please log in and configure your profile to view AI insights.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          else if (_isLoadingPlant)
            const Text(
              'Loading crop growth cycle...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            )
          else if (!hasPlant)
            Text(
              'No experimental plant assigned yet. Go to Settings → Add Experimental Plant to start growth tracking.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            )
          else ...[
            Text(
              stageTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.greenAccent.shade400, size: 14),
                const SizedBox(width: 6),
                Text(
                  harvestLine,
                  style: TextStyle(
                    color: Colors.greenAccent.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.12), height: 1),
            const SizedBox(height: 12),
            Text(
              stageDescription,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}