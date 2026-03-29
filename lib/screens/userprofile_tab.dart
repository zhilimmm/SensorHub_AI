import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class SettingsTab extends StatefulWidget {
  final bool isLoggedIn; 
  const SettingsTab({super.key, this.isLoggedIn = true});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _alertsEnabled = true;
  bool _reportsEnabled = true;
  bool _updatesEnabled = false;

  bool _isEditingAccount = false;
  bool _isLoading = true; 

  final TextEditingController _usernameController = TextEditingController();
  
  String _selectedCountry = 'Malaysia';
  String _selectedState = 'Selangor';
  String _selectedCity = 'Shah Alam';
  String _selectedLanguage = 'English';

  final List<String> _countryOptions = ['Malaysia', 'Singapore', 'Indonesia', 'Thailand'];
  final List<String> _stateOptions = ['Selangor', 'Kuala Lumpur', 'Penang', 'Johor', 'Perak'];
  final List<String> _cityOptions = ['Shah Alam', 'Kapar', 'Klang', 'Subang Jaya', 'Petaling Jaya'];
  final List<String> _languageOptions = ['English', 'Bahasa Melayu', 'Chinese'];

  final Color _bgColor = const Color(0xFFEDF7F0); 
  final Color _darkGreen = const Color(0xFF0A3B24); 
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      if (_isEditingAccount) setState(() {});
    });
    
    if (widget.isLoggedIn) {
      _getProfile(); 
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _getProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        _usernameController.text = (data['username'] ?? 'New User') as String;
        _selectedCountry = (data['country'] ?? 'Malaysia') as String;
        _selectedState = (data['state'] ?? 'Selangor') as String;
        _selectedCity = (data['city'] ?? 'Shah Alam') as String;
        _selectedLanguage = (data['language'] ?? 'English') as String;
      } else {
        _usernameController.text = 'New User'; 
      }
    } catch (error) {
      debugPrint('Error loading profile: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final updates = {
        'id': user.id,
        'username': _usernameController.text,
        'country': _selectedCountry,
        'state': _selectedState,
        'city': _selectedCity,
        'language': _selectedLanguage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('profiles').upsert(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
        setState(() => _isEditingAccount = false); 
      }
    } catch (error) {
      debugPrint('Error saving profile: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isEditingAccount && widget.isLoggedIn) {
      return Container(
        color: _bgColor,
        child: const Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Container(
      color: _bgColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildProfileSection(),
              const SizedBox(height: 32),
              _buildAccountDetails(),
              const SizedBox(height: 32),
              _buildImpactStats(),
              const SizedBox(height: 32),
              _buildNotificationPreferences(),
              const SizedBox(height: 40),
              if (widget.isLoggedIn) _buildFooterWithOvalButtons(), 
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SizedBox(
      width: double.infinity, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Text(
            'ACCOUNT MANAGEMENT',
            textAlign: TextAlign.center, 
            style: TextStyle(color: widget.isLoggedIn ? const Color(0xFF047857) : Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            'User Profile & Settings', 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.isLoggedIn ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                // --- UPDATE STARTS HERE ---
                // We use conditional logic to switch between the active dynamic photo
                // and the greyed-out icon requested in image_319bd8.png
                child: widget.isLoggedIn 
                  ? const CircleAvatar(
                      radius: 50,
                      // The active dynamic photo (as seen in image_3197bc.png)
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1560250097-0b93528c311a?q=80&w=256&auto=format&fit=crop'), 
                    )
                  : CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200, // Matching the light grey background
                      // The generic person icon placeholder (matching image_319bd8.png)
                      child: Icon(Icons.person, size: 70, color: Colors.grey.shade500),
                    ),
                // --- UPDATE ENDS HERE ---
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: widget.isLoggedIn ? _darkGreen : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            !widget.isLoggedIn ? 'Guest User' : (_usernameController.text.isEmpty ? 'Unknown User' : _usernameController.text),
            style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Account Details', style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold)),
            
            if (widget.isLoggedIn) GestureDetector(
              onTap: () {
                if (_isEditingAccount) {
                  _updateProfile(); 
                } else {
                  setState(() => _isEditingAccount = true); 
                }
              },
              child: _isEditingAccount
                  ? _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('Done', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                  : Icon(Icons.edit, color: Colors.grey.shade600, size: 18),
            )
          ],
        ),
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
              _buildAccountRowText(Icons.alternate_email, 'Username', _usernameController),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowDropdown(Icons.public, 'Country', _selectedCountry, _countryOptions, (val) {
                if (val != null) setState(() => _selectedCountry = val);
              }),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowDropdown(Icons.map, 'State', _selectedState, _stateOptions, (val) {
                if (val != null) setState(() => _selectedState = val);
              }),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowDropdown(Icons.location_city, 'City', _selectedCity, _cityOptions, (val) {
                if (val != null) setState(() => _selectedCity = val);
              }),
              Divider(color: Colors.grey.shade200, height: 1),
              _buildAccountRowDropdown(Icons.language, 'Language', _selectedLanguage, _languageOptions, (val) {
                if (val != null) setState(() => _selectedLanguage = val);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRowText(IconData icon, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: _isEditingAccount && widget.isLoggedIn
                ? TextField(
                    controller: controller,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.only(bottom: 4),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2)),
                    ),
                  )
                : Text(
                    !widget.isLoggedIn ? '--' : controller.text,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRowDropdown(IconData icon, String label, String currentValue, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: _isEditingAccount && widget.isLoggedIn
                ? Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<String>(
                      value: currentValue,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                      style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                      underline: Container(height: 1, color: Colors.grey.shade300),
                      onChanged: onChanged,
                      items: options.map<DropdownMenuItem<String>>((String option) {
                        return DropdownMenuItem<String>(value: option, child: Text(option));
                      }).toList(),
                    ),
                  )
                : Text(
                    !widget.isLoggedIn ? '--' : currentValue,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
          ),
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
            Text('Impact Stats', style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Last 30 Days', style: TextStyle(color: widget.isLoggedIn ? Colors.green.shade700 : Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.eco, 'CROP YIELD', widget.isLoggedIn ? '+18%' : '--')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.water_drop, 'WATER SAVED', widget.isLoggedIn ? '4.2k L' : '--')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.bolt, 'ENERGY EFF.', widget.isLoggedIn ? '94%' : '--', iconColor: widget.isLoggedIn ? Colors.orange.shade700 : null)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.co2, 'CO2 REDUCED', widget.isLoggedIn ? '120kg' : '--')),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isLoggedIn ? const Color(0xFF69FFA8) : Colors.grey.shade300, 
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.psychology, color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade500, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                    child: Text(widget.isLoggedIn ? 'AI DRIVEN' : 'OFFLINE', style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text('NUTRIENT PRECISION', style: TextStyle(color: widget.isLoggedIn ? _darkGreen.withOpacity(0.7) : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(widget.isLoggedIn ? '99.8%' : '--', style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade700, fontSize: 24, fontWeight: FontWeight.w900)),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: widget.isLoggedIn ? (iconColor ?? _darkGreen) : Colors.grey.shade400, size: 24),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notification Preferences', style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
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
            decoration: BoxDecoration(color: widget.isLoggedIn ? Colors.green.shade50 : Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade400, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: widget.isLoggedIn ? _darkGreen : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch(
            value: widget.isLoggedIn ? value : false,
            onChanged: widget.isLoggedIn ? onChanged : null,
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