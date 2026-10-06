import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isLoggedIn;
  
  const NotificationsScreen({super.key, required this.isLoggedIn});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchHistoricalAlerts();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistoricalAlerts() async {
    setState(() => _isLoading = true);
    try {
      // Pull the last 100 records to scan for historical alerts
      final response = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      List<Map<String, dynamic>> alerts = [];

      for (var row in response) {
        DateTime dt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();

        double? temp = (row['temperature'] as num?)?.toDouble();
        double? humid = (row['humidity'] as num?)?.toDouble();
        int? moist = (row['soil_moisture'] as num?)?.toInt();

        // Check for Temperature Alerts
        if (temp != null && temp > 28.0) {
          bool isCritical = temp > 32.0;
          alerts.add({
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'typeColor': isCritical ? const Color(0xFFE53935) : const Color(0xFFF57C00),
            'bgColor': isCritical ? Colors.red.shade50 : Colors.orange.shade50,
            'icon': Icons.thermostat,
            'title': isCritical ? 'Extreme Temperature' : 'High Temperature',
            'message': 'Environment reached ${temp.toStringAsFixed(1)}°C. Consider activating supplementary ventilation.',
            'timestamp': dt,
          });
        }

        // Check for Humidity Alerts
        if (humid != null && humid > 90.0) {
          bool isCritical = humid > 95.0;
          alerts.add({
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'typeColor': isCritical ? const Color(0xFFE53935) : const Color(0xFFF57C00),
            'bgColor': isCritical ? Colors.red.shade50 : Colors.orange.shade50,
            'icon': Icons.cloud_off,
            'title': isCritical ? 'Severe Humidity' : 'Elevated Humidity',
            'message': 'Atmospheric humidity exceeded ${humid.toStringAsFixed(0)}%. Ventilation required to prevent fungal growth.',
            'timestamp': dt,
          });
        }

        // Check for Moisture Alerts
        if (moist != null && (moist < 70 || moist > 95)) {
          bool isCritical = moist < 50 || moist > 98;
          bool isDry = moist < 70;
          alerts.add({
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'typeColor': isCritical ? const Color(0xFFE53935) : const Color(0xFFF57C00),
            'bgColor': isCritical ? Colors.red.shade50 : Colors.orange.shade50,
            'icon': Icons.water_drop_outlined,
            'title': isDry ? 'Extreme Moisture Drop' : 'Waterlogged Soil',
            'message': isDry
                ? 'Soil has dropped below $moist%. Immediate irrigation required to prevent root stress.'
                : 'Soil moisture peaked at $moist%. Automated watering cycles have been suspended.',
            'timestamp': dt,
          });
        }
      }

      // Sort properly by date just in case
      alerts.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      // Map dynamic Time Ago strings formatting exactly like the mockup
      for (var alert in alerts) {
        alert['timeAgo'] = _getMockupTimeAgo(alert['timestamp']);
      }

      if (mounted) {
        setState(() {
          _notifications = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMockupTimeAgo(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 1) {
      return DateFormat('MMM dd').format(dateTime).toUpperCase();
    } else if (diff.inDays == 1) {
      return '1 DAY AGO';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'HOUR' : 'HOURS'} AGO';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} MIN AGO';
    } else {
      return 'JUST NOW';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Slightly off-white background from mockup
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF064E3B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications', 
          style: TextStyle(color: Color(0xFF022C22), fontWeight: FontWeight.w900, fontSize: 20)
        ),
        titleSpacing: 0, // Aligns title closely to the back button
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF047857)))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'Stay updated with your botanical ecosystem.', 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF047857),
                  onRefresh: _fetchHistoricalAlerts,
                  child: _buildNotificationsList(),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildNotificationsList() {
    if (!widget.isLoggedIn) {
      return _buildEmptyState(Icons.cloud_off, 'System offline', 'Please log in to view alert history.');
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(Icons.check_circle_outline, 'All Clear', 'No environmental alerts recorded recently.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final alert = _notifications[index];
        
        // Logic to inject the "OLDER" divider
        bool showOlderDivider = false;
        if (index > 0) {
          final currentAlert = _notifications[index];
          final prevAlert = _notifications[index - 1];
          bool isCurrentOlder = DateTime.now().difference(currentAlert['timestamp']).inDays > 1;
          bool isPrevOlder = DateTime.now().difference(prevAlert['timestamp']).inDays > 1;
          
          if (isCurrentOlder && !isPrevOlder) {
            showOlderDivider = true;
          }
        }

        Widget card = Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16), 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02), 
                blurRadius: 10, 
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: alert['bgColor'],
                child: Icon(alert['icon'], color: alert['typeColor'], size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          alert['type'], 
                          style: TextStyle(
                            color: alert['typeColor'], 
                            fontSize: 9, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.5
                          )
                        ),
                        Text(
                          alert['timeAgo'], 
                          style: TextStyle(
                            color: Colors.grey.shade400, 
                            fontSize: 9, 
                            fontWeight: FontWeight.w800, 
                            letterSpacing: 0.5
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert['title'], 
                      style: const TextStyle(
                        color: Color(0xFF222222), 
                        fontWeight: FontWeight.bold, 
                        fontSize: 15
                      )
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert['message'], 
                      style: TextStyle(
                        color: Colors.grey.shade600, 
                        fontSize: 12.5, 
                        fontWeight: FontWeight.w500,
                        height: 1.4
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (showOlderDivider) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Text('OLDER', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(width: 12),
                    Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  ],
                ),
              ),
              card,
            ],
          );
        }

        return card;
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF022C22))),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}