import 'package:flutter/material.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // State for notification switches
  bool _alertsEnabled = true;
  bool _reportsEnabled = true;
  bool _updatesEnabled = false;

  // Design Colors
  final Color _bgColor = const Color(0xFFEDF7F0); 
  final Color _darkGreen = const Color(0xFF0A3B24); 
  final Color _vibrantGreen = const Color(0xFF00E676); 
  final Color _cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderUppercaseLabel(),
              const SizedBox(height: 24),
              _buildProfileSectionWithoutButtons(),
              const SizedBox(height: 32),
              _buildAccountDetailsWithEditIcons(),
              const SizedBox(height: 32),
              _buildImpactStats(),
              const SizedBox(height: 32),
              _buildNotificationPreferences(),
              const SizedBox(height: 40),
              _buildFooterWithOvalButtons(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderUppercaseLabel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'PROFILE & SETTINGS',
              style: TextStyle(
                color: _vibrantGreen, 
                fontSize: 10, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 2
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Icon(Icons.check, color: Colors.green.shade600, size: 16),
        )
      ],
    );
  }

  Widget _buildProfileSectionWithoutButtons() {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1560250097-0b93528c311a?q=80&w=256&auto=format&fit=crop'), 
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _darkGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Alex Harrison',
          style: TextStyle(color: _darkGreen, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Smart Gardener since 2023',
          style: TextStyle(color: Colors.green.shade600, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsWithEditIcons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account Details', style: TextStyle(color: _darkGreen, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildAccountRowWithEditIcon(Icons.alternate_email, 'Username', 'alex_h'),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowWithEditIcon(Icons.location_on, 'Location', 'Kapar, Selangor'),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowWithEditIcon(Icons.language, 'Language', 'English'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRowWithEditIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Icon(Icons.edit, color: Colors.grey.shade400, size: 14), 
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildImpactStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Impact Stats', style: TextStyle(color: _darkGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Last 30 Days', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.eco, 'CROP YIELD', '+18%')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.water_drop, 'WATER SAVED', '4.2k L')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.bolt, 'ENERGY EFF.', '94%', iconColor: Colors.orange.shade700)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.co2, 'CO2 REDUCED', '120kg')),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF69FFA8), 
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF69FFA8).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.psychology, color: _darkGreen, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('AI DRIVEN', style: TextStyle(color: _darkGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text('NUTRIENT PRECISION', style: TextStyle(color: _darkGreen.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('99.8%', style: TextStyle(color: _darkGreen, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? _darkGreen, size: 24),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: _darkGreen, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notification Preferences', style: TextStyle(color: _darkGreen, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildNotificationRow(Icons.notifications_active, 'Alerts', 'Real-time critical sensors warnings', _alertsEnabled, (val) => setState(() => _alertsEnabled = val)),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildNotificationRow(Icons.summarize, 'Reports', 'Weekly performance summaries', _reportsEnabled, (val) => setState(() => _reportsEnabled = val)),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildNotificationRow(Icons.system_update, 'Updates', 'New AI features and firmware', _updatesEnabled, (val) => setState(() => _updatesEnabled = val)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationRow(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: _darkGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: _darkGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterWithOvalButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.switch_account, color: _darkGreen, size: 18),
            label: Text('Switch Account', style: TextStyle(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white, 
              side: const BorderSide(color: Colors.white, width: 3), 
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), 
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: Colors.white, size: 20), 
            label: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), 
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B), 
              elevation: 4,
              shadowColor: const Color(0xFFC0392B).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), 
            ),
          ),
        ),
      ],
    );
  }
}