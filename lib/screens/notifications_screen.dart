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
  List _notifications = [];

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
      final response = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      List alerts = [];

      for (var row in response) {
        DateTime dt =
            DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now();

        double? temp = (row['temperature'] as num?)?.toDouble();
        double? humid = (row['humidity'] as num?)?.toDouble();
        int? moist = (row['soil_moisture'] as num?)?.toInt();

        // Check for Temperature Alerts
        if (temp != null && temp > 28.0) {
          bool isCritical = temp > 32.0;
          alerts.add({
            'isCritical': isCritical,
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'icon': Icons.thermostat,
            'title': isCritical ? 'Extreme Temperature' : 'High Temperature',
            'message':
                'Environment reached ${temp.toStringAsFixed(1)}°C. Consider activating supplementary ventilation.',
            'timestamp': dt,
          });
        }

        // Check for Humidity Alerts
        if (humid != null && humid > 90.0) {
          bool isCritical = humid > 95.0;
          alerts.add({
            'isCritical': isCritical,
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'icon': Icons.cloud_off,
            'title': isCritical ? 'Severe Humidity' : 'Elevated Humidity',
            'message':
                'Atmospheric humidity exceeded ${humid.toStringAsFixed(0)}%. Ventilation required to prevent fungal growth.',
            'timestamp': dt,
          });
        }

        // Check for Moisture Alerts
        if (moist != null && (moist < 70 || moist > 95)) {
          bool isCritical = moist < 50 || moist > 98;
          bool isDry = moist < 70;
          alerts.add({
            'isCritical': isCritical,
            'type': isCritical ? 'CRITICAL' : 'WARNING',
            'icon': Icons.water_drop_outlined,
            'title': isDry
                ? (isCritical ? 'Extreme Moisture Drop' : 'Low Soil Moisture')
                : 'Waterlogged Soil',
            'message': isDry
                ? 'Soil has dropped below $moist%. Immediate irrigation required to prevent root stress.'
                : 'Soil moisture peaked at $moist%. Automated watering cycles have been suspended.',
            'timestamp': dt,
          });
        }
      }

      alerts.sort((a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF064E3B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Color(0xFF022C22),
              fontWeight: FontWeight.w900,
              fontSize: 20),
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF047857)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Text(
                    'Stay updated with your botanical ecosystem.',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
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
      return _buildEmptyState(Icons.cloud_off, 'System offline',
          'Please log in to view alert history.');
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(Icons.check_circle_outline, 'All Clear',
          'No environmental alerts recorded recently.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final alert = _notifications[index];
        final bool isCritical =
            alert['isCritical'] == true || alert['type'] == 'CRITICAL';

        // High-contrast palette: Deep Crimson Red for CRITICAL vs Warm Amber for WARNING
        final Color cardBg =
            isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFFFBEB);
        final Color borderColor =
            isCritical ? const Color(0xFFF87171) : const Color(0xFFFBBF24);
        final Color stripeColor =
            isCritical ? const Color(0xFFB91C1C) : const Color(0xFFD97706);
        final Color iconCircleBg =
            isCritical ? const Color(0xFFB91C1C) : const Color(0xFFFEF3C7);
        final Color iconColor =
            isCritical ? Colors.white : const Color(0xFFB45309);
        final Color badgeBg =
            isCritical ? const Color(0xFFB91C1C) : const Color(0xFFFEF3C7);
        final Color badgeText =
            isCritical ? Colors.white : const Color(0xFF92400E);

        bool showOlderDivider = false;
        if (index > 0) {
          final currentAlert = _notifications[index];
          final prevAlert = _notifications[index - 1];
          bool isCurrentOlder =
              DateTime.now().difference(currentAlert['timestamp']).inDays > 1;
          bool isPrevOlder =
              DateTime.now().difference(prevAlert['timestamp']).inDays > 1;

          if (isCurrentOlder && !isPrevOlder) {
            showOlderDivider = true;
          }
        }

        Widget card = Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isCritical ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: stripeColor.withOpacity(isCritical ? 0.14 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: isCritical ? 7 : 5, color: stripeColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: iconCircleBg,
                            child: Icon(
                              alert['icon'],
                              color: iconColor,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCritical) ...[
                                            const Icon(
                                              Icons.warning_rounded,
                                              size: 11,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            alert['type'],
                                            style: TextStyle(
                                              color: badgeText,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      alert['timeAgo'],
                                      style: TextStyle(
                                        color: isCritical
                                            ? const Color(0xFF991B1B)
                                            : Colors.grey.shade500,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alert['title'],
                                  style: TextStyle(
                                    color: isCritical
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  alert['message'],
                                  style: TextStyle(
                                    color: isCritical
                                        ? const Color(0xFF7F1D1D)
                                            .withOpacity(0.9)
                                        : const Color(0xFF4B5563),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (showOlderDivider) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Text('OLDER',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            Divider(color: Colors.grey.shade300, thickness: 1)),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF022C22))),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}