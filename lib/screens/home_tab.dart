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
  String _selectedZone = 'Zone A: Seeding Chamber'; 
  final List<String> _zones = [
    'Zone A: Seeding Chamber',  
    'Zone B: Harvest Ready Bay', 
    'Zone C: Idle', 
    'All Zones'
  ];
  
  String _fetchedUserName = 'Loading...';
  // ⭐ NEW: Add a variable to store the user's location
  String _fetchedLocation = 'Loading...'; 
  bool _hasProfileData = false; 

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserProfile();
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // ⭐ UPDATE: Select city, state, and country from Supabase
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
            
            // ⭐ Determine the best location string to show
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
            _fetchedLocation = 'Location not set'; // Default for new users
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
    String currentZoneType = 'A';
    if (_selectedZone.contains('Zone B')) currentZoneType = 'B';
    if (_selectedZone.contains('Zone C')) currentZoneType = 'C';
    if (_selectedZone.contains('All Zones')) currentZoneType = 'ALL';

    // ⭐ Force into Grey/Idle Zone C if they are logged out OR if they are a new account with no data
    if (!widget.isLoggedIn || !_hasProfileData) {
      currentZoneType = 'C';
    }

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
                _buildZoneDropdown(),
                const SizedBox(height: 24),
                const Text('OVERALL HEALTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF064E3B), letterSpacing: 1.2)),
                const SizedBox(height: 8),
                _buildHealthWidget(currentZoneType),
                const SizedBox(height: 24),
                _buildLiveTelemetryWidget(currentZoneType),
                const SizedBox(height: 32), 
                _buildActiveAlertsWidget(currentZoneType),
                const SizedBox(height: 32),
                _buildNextActionsWidget(currentZoneType),
                const SizedBox(height: 24),
                _buildAIPredictionWidget(currentZoneType, widget.isLoggedIn && _hasProfileData),
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
                          // ⭐ Inject the dynamic location here!
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
                              // ⭐ Hide temperature and condition if not configured
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
                      // ⭐ Hide bottom metrics if not configured
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

  Widget _buildZoneDropdown() {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, 
          // ⭐ Lock to Zone C if no data
          value: (widget.isLoggedIn && _hasProfileData) ? _selectedZone : 'Zone C: Idle',
          icon: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 24), 
          elevation: 8, 
          borderRadius: BorderRadius.circular(24), 
          dropdownColor: Colors.white, 
          items: _zones.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Icon(Icons.local_florist, color: (widget.isLoggedIn && _hasProfileData) ? const Color(0xFF064E3B) : Colors.grey.shade500, size: 22),
                  const SizedBox(width: 12),
                  Text(value, style: TextStyle(color: (widget.isLoggedIn && _hasProfileData) ? const Color(0xFF064E3B) : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)), 
                ],
              ),
            );
          }).toList(),
          // ⭐ Disable click if no data
          onChanged: (widget.isLoggedIn && _hasProfileData) ? (String? newValue) {
            if (newValue != null) {
              setState(() { _selectedZone = newValue; });
            }
          } : null, 
        ),
      ),
    );
  }

  Widget _buildHealthWidget(String zoneType) {
    Color mainBgColor = const Color(0xFFA1E6A1); 
    Color darkGreen = const Color(0xFF064E3B);
    Color progressFillColor = const Color.fromARGB(255, 62, 154, 109); 
    Color progressTrackColor = const Color(0xFFE8F5E9); 

    String healthStatus;
    String healthDesc;
    double progressValue;
    String percentage;

    if (zoneType == 'A') {
      healthStatus = 'Excellent';
      healthDesc = 'Early growth stage optimal';
      progressValue = 0.94;
      percentage = '94%';
    } else if (zoneType == 'B') {
      healthStatus = 'Peak';
      healthDesc = 'Ready for harvest window';
      progressValue = 0.99;
      percentage = '99%';
    } else if (zoneType == 'C') {
      mainBgColor = Colors.grey.shade200;
      darkGreen = Colors.grey.shade700;
      progressFillColor = Colors.grey.shade500;
      progressTrackColor = Colors.grey.shade300;
      healthStatus = 'Standby';
      healthDesc = 'No active crops assigned';
      progressValue = 0.0;
      percentage = '0%';
    } else {
      healthStatus = 'Optimal';
      healthDesc = 'Greenhouse overall average';
      progressValue = 0.96;
      percentage = '96%';
    }

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
                Text(healthStatus, style: TextStyle(color: darkGreen, fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(healthDesc, style: TextStyle(color: darkGreen, fontSize: 12, fontWeight: FontWeight.w500)),
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
                      value: progressValue, 
                      backgroundColor: progressTrackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(progressFillColor),
                      strokeWidth: 8, 
                    ),
                  ),
                  Text(percentage, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: darkGreen)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryWidget(String zoneType) {
    List<Widget> telemetryPills;

    if (zoneType == 'A') {
      telemetryPills = [
        _buildTelemetryPill('MOIST', '85%', Icons.water_drop, 'optimal'), 
        const SizedBox(width: 10),
        _buildTelemetryPill('LUX', '800', Icons.light_mode, 'optimal'), 
        const SizedBox(width: 10),
        _buildTelemetryPill('TEMP', '24°', Icons.thermostat, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('PH', '6.2', Icons.science, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('HUMID', '90%', Icons.air, 'warning'),
      ];
    } else if (zoneType == 'B') {
      telemetryPills = [
        _buildTelemetryPill('MOIST', '40%', Icons.water_drop, 'warning'), 
        const SizedBox(width: 10),
        _buildTelemetryPill('LUX', '1.8k', Icons.light_mode, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('TEMP', '26°', Icons.thermostat, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('PH', '6.5', Icons.science, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('HUMID', '55%', Icons.air, 'optimal'),
      ];
    } else if (zoneType == 'C') {
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
    } else {
      telemetryPills = [
        _buildTelemetryPill('MOIST', '62%', Icons.water_drop, 'optimal'), 
        const SizedBox(width: 10),
        _buildTelemetryPill('LUX', '1.3k', Icons.light_mode, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('TEMP', '25°', Icons.thermostat, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('PH', '6.3', Icons.science, 'optimal'),
        const SizedBox(width: 10),
        _buildTelemetryPill('HUMID', '72%', Icons.air, 'optimal'),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('LIVE TELEMETRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)),
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

  Widget _buildActiveAlertsWidget(String zoneType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('VIEW MORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (zoneType == 'A') ...[
          _buildNewAlertRow(Icons.water_drop, Colors.blue.shade500, '(Zone A) Humidity exceeds 85%', 'Seeding Tray Tray #4', '5m ago'),
          const SizedBox(height: 12),
          _buildNewAlertRow(Icons.lightbulb, Colors.amber.shade600, '(Zone A) Grow lights active', 'Supplemental trays 1-10', '1h ago'),
        ] else if (zoneType == 'B') ...[
          _buildNewAlertRow(Icons.check_circle, Colors.green.shade600, '(Zone B) Ready for harvest', 'Harvest window is open', '1h ago'),
          const SizedBox(height: 12),
          _buildNewAlertRow(Icons.warning_rounded, Colors.orange.shade700, '(Zone B) Low Moisture Detected', 'Pre-harvest drying in progress', '2h ago'),
        ] else if (zoneType == 'C') ...[
          _buildEmptyStateRow(Icons.notifications_paused, 'No active alerts for this zone.'),
        ] else ...[
          _buildNewAlertRow(Icons.water_drop, Colors.blue.shade500, '(Zone A) Humidity exceeds 85%', 'Seeding Tray Tray #4', '5m ago'),
          const SizedBox(height: 12),
          _buildNewAlertRow(Icons.check_circle, Colors.green.shade600, '(Zone B) Ready for harvest', 'Harvest window is open', '1h ago'),
        ]
      ],
    );
  }

  Widget _buildNextActionsWidget(String zoneType) {
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
        
        if (zoneType == 'A') ...[
          _buildNewActionRow(Icons.air, Colors.blue.shade100, Colors.blue.shade700, '(Zone A) Gentle Ventilation', 'Seedling propagation chamber'),
          const SizedBox(height: 12),
          _buildNewActionRow(Icons.eco, Colors.green.shade100, Colors.green.shade800, '(Zone A) Mist Propagation', 'Rooting trays 1-10Misting Cycle'),
        ] else if (zoneType == 'B') ...[
          _buildNewActionRow(Icons.content_cut, Colors.orange.shade100, Colors.orange.shade800, '(Zone B) Initiate Harvest', 'Manual harvest required'),
          const SizedBox(height: 12),
          _buildNewActionRow(Icons.cleaning_services, Colors.blue.shade100, Colors.blue.shade700, '(Zone B) Flush Water Lines', 'Hydroponic System A cleaning'),
        ] else if (zoneType == 'C') ...[
           _buildEmptyStateRow(Icons.event_busy, 'No upcoming actions estimated.'),
        ] else ...[
          _buildNewActionRow(Icons.air, Colors.blue.shade100, Colors.blue.shade700, '(Zone A) Gentle Ventilation', 'Seedling propagation chamber'),
          const SizedBox(height: 12),
          _buildNewActionRow(Icons.content_cut, Colors.orange.shade100, Colors.orange.shade800, '(Zone B) Initiate Harvest', 'Manual harvest required'),
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

  Widget _buildAIPredictionWidget(String zoneType, bool isActive) {
    String aiMessage;

    // ⭐ Handle the offline/unconfigured state first
    if (!isActive) {
      aiMessage = 'System offline. Please log in and configure your profile to view AI insights.';
    } else if (zoneType == 'A') {
      aiMessage = '(Zone A) Seedling roots established. True leaves expected in 5 days.';
    } else if (zoneType == 'B') {
      aiMessage = '(Zone B) Fruit ripening complete. Optimal Sugar Brix content detected.';
    } else if (zoneType == 'C') {
      aiMessage = '(Zone C) Zone is currently idle. System standing by for new crop assignment.';
    } else {
      aiMessage = '(All Zones) Overall resource distribution is balanced. Water usage optimized by 15%.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // ⭐ Change background to grey if not active
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

class DummyNotificationsScreen extends StatelessWidget {
  const DummyNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Here is the Notifications Page')),
    );
  }
}

class DummyControlsScreen extends StatelessWidget {
  const DummyControlsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Controls / Schedule')),
      body: const Center(child: Text('Here is the Controls Page')),
    );
  }
}