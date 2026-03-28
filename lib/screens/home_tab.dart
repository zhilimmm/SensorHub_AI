import 'package:flutter/material.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // The state specific to the Home Tab
  String _selectedZone = 'Zone A: Tropical Ferns'; 
  final List<String> _zones = [
    'Zone A: Tropical Ferns', 
    'Zone B: Succulent Bay', 
    'Zone C: Rare Orchids', 
    'All Zones'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            _buildHealthWidget(),
            const SizedBox(height: 24),

            _buildLiveTelemetryWidget(),
            const SizedBox(height: 32), 

            _buildActiveAlertsWidget(),
            const SizedBox(height: 32),

            _buildNextActionsWidget(),
            const SizedBox(height: 24),

            _buildAIPredictionWidget(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS FOR HOME TAB ---

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
          const Text.rich(
            TextSpan(
              text: 'Hi, ',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF333333)), 
              children: [
                TextSpan(text: 'Zhi Lim', style: TextStyle(color: Colors.green)), 
                TextSpan(text: '! 👋'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your ecosystem is flourishing today.',
            style: TextStyle(fontSize: 14, color: const Color(0xFF333333).withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFAED9F1), 
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FRIDAY, MARCH 27, 2026', style: TextStyle(color: Color(0xFF666666), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        SizedBox(height: 4),
                        Text('Kuala Lumpur', style: TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Row(
                      children: [
                        const Row(children: [Icon(Icons.wb_sunny, color: Colors.orange, size: 28), Icon(Icons.cloud, color: Colors.white, size: 28)],),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('32°C', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF222222), height: 1.1)),
                            Text('Partly Cloudy', style: TextStyle(color: const Color(0xFF666666), fontSize: 10, fontWeight: FontWeight.w700)),
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
                    _buildWeatherDetail(Icons.air, '12 km/h'),
                    _buildWeatherDetail(Icons.water_drop_outlined, '68%'),
                    _buildWeatherDetail(Icons.umbrella_outlined, '10% rain'),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 16),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF333333))),
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
          value: _selectedZone,
          icon: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 24), 
          elevation: 8, 
          borderRadius: BorderRadius.circular(24), 
          dropdownColor: Colors.white, 
          items: _zones.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  const Icon(Icons.local_florist, color: Color(0xFF064E3B), size: 22),
                  const SizedBox(width: 12),
                  Text(value, style: const TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() { _selectedZone = newValue; });
            }
          },
        ),
      ),
    );
  }

  Widget _buildHealthWidget() {
    const Color mainBgColor = Color(0xFFA1E6A1); 
    const Color darkGreen = Color(0xFF064E3B);
    const Color progressFillColor = Color.fromARGB(255, 62, 154, 109); 
    const Color progressTrackColor = Color(0xFFE8F5E9); 

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: mainBgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HEALTH INDEX', style: TextStyle(color: darkGreen.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Excellent', style: TextStyle(color: darkGreen, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Optimal growing conditions', style: TextStyle(color: darkGreen, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
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
                      value: 0.94, 
                      backgroundColor: progressTrackColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(progressFillColor),
                      strokeWidth: 8, 
                    ),
                  ),
                  const Text('94%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: darkGreen)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryWidget() {
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
              children: [
                _buildTelemetryPill('MOIST', '64%', Icons.water_drop, 'optimal'),
                const SizedBox(width: 10),
                _buildTelemetryPill('LUX', '1.2k', Icons.light_mode, 'warning'),
                const SizedBox(width: 10),
                _buildTelemetryPill('TEMP', '28°', Icons.thermostat, 'optimal'),
                const SizedBox(width: 10),
                _buildTelemetryPill('PH', '6.8', Icons.science, 'optimal'),
                const SizedBox(width: 10),
                _buildTelemetryPill('HUMID', '82%', Icons.air, 'optimal'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.greenAccent.shade400, 'Optimal'),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.orange, 'Warning'),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.redAccent, 'Danger'),
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
    Color statusColor;
    if (status == 'optimal') {
      statusColor = Colors.greenAccent.shade700;
    } else if (status == 'warning') {
      statusColor = Colors.orange;
    } else if (status == 'danger') {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Colors.grey; 
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white, 
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF222222))),
        ],
      ),
    );
  }

  Widget _buildActiveAlertsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            Text('VIEW MORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        _buildNewAlertRow(Icons.warning_rounded, Colors.redAccent.shade700, 'Low Nitrogen detected', 'Zone B - Tomato Bed', '2m ago'),
        const SizedBox(height: 12),
        _buildNewAlertRow(Icons.schedule, Colors.orange.shade700, 'Filter change recommended', 'Hydroponic System A', '1h ago'),
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

  Widget _buildNextActionsWidget() {
    return Column( 
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Next Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            Text('View Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
          ],
        ),
        const SizedBox(height: 16),
        _buildNewActionRow(Icons.water_drop, Colors.blue.shade100, Colors.blue.shade700, 'Irrigation Phase 2', 'Scheduled at 2:00 PM Today'),
        const SizedBox(height: 12),
        _buildNewActionRow(Icons.eco, Colors.orange.shade100, Colors.orange.shade800, 'NPK Supplementing', 'Scheduled for tomorrow'),
      ],
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

  Widget _buildAIPredictionWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF022C22), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.green.shade900)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              Text('AI PREDICTION', style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Expected harvest in 12 days. Current growth rate is 4% faster than average.',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('VIEW FULL ANALYSIS', style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: Colors.greenAccent.shade400, size: 16),
            ],
          )
        ],
      ),
    );
  }
}