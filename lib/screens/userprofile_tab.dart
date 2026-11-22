import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../main.dart';

class CropPreset {
  final String name;
  final int suggestedDays;
  final String tempRange;
  final String moistureRange;
  final String humidityRange;
  final String phRange;
  final String note;

  const CropPreset({
    required this.name,
    required this.suggestedDays,
    required this.tempRange,
    required this.moistureRange,
    required this.humidityRange,
    required this.phRange,
    required this.note,
  });
}

const List<CropPreset> kSuggestedCrops = [
  CropPreset(
    name: 'Sweet Potato Leaves',
    suggestedDays: 40,
    tempRange: '24–30°C',
    moistureRange: '60–80%',
    humidityRange: '65–85%',
    phRange: '5.8–6.8',
    note: 'Fast-growing tropical leafy green; thrives in warm Malaysian greenhouse conditions.',
  ),
  CropPreset(
    name: 'Lettuce',
    suggestedDays: 45,
    tempRange: '15–24°C',
    moistureRange: '60–75%',
    humidityRange: '50–70%',
    phRange: '6.0–6.8',
    note: 'Cool-season leafy crop; requires active ventilation to prevent tip-burn above 26°C.',
  ),
  CropPreset(
    name: 'Pak Choi (Bok Choy)',
    suggestedDays: 35,
    tempRange: '18–26°C',
    moistureRange: '65–80%',
    humidityRange: '60–75%',
    phRange: '6.0–7.0',
    note: 'Short harvest cycle with steady soil moisture requirements.',
  ),
  CropPreset(
    name: 'Spinach (Bayam)',
    suggestedDays: 30,
    tempRange: '20–30°C',
    moistureRange: '60–75%',
    humidityRange: '60–80%',
    phRange: '6.0–7.0',
    note: 'Quick 30-day cycle; tolerant of warm indoor chambers with regular misting.',
  ),
  CropPreset(
    name: 'Sweet Basil',
    suggestedDays: 50,
    tempRange: '22–30°C',
    moistureRange: '50–70%',
    humidityRange: '50–70%',
    phRange: '5.5–6.5',
    note: 'Aromatic herb preferring moderate soil moisture and bright light.',
  ),
];

class SettingsTab extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback? onPlantChanged;
  final VoidCallback? onProfileUpdated;

  const SettingsTab({
    super.key,
    this.isLoggedIn = true,
    this.onPlantChanged,
    this.onProfileUpdated,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final ScrollController _pageScrollController = ScrollController();

  bool _alertsEnabled = true;
  bool _reportsEnabled = true;
  bool _updatesEnabled = false;

  bool _isEditingAccount = false;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  final TextEditingController _usernameController = TextEditingController();

  bool get _hasProfileData => widget.isLoggedIn && _usernameController.text.trim().isNotEmpty;

  String? _avatarUrl;
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedCity;
  String? _selectedLanguage;

  String? _activePlantName;
  int? _activeHarvestDays;

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
      _loadInitialData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _getProfile(),
      _getUserPlant(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _getProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _usernameController.text = data['username'] as String? ?? '';
        _avatarUrl = data['avatar_url'] as String?;
        _selectedCountry = data['country'] as String?;
        _selectedState = data['state'] as String?;
        _selectedCity = data['city'] as String?;
        _selectedLanguage = data['language'] as String?;
      } else {
        _usernameController.text = '';
        _avatarUrl = null;
        _selectedCountry = null;
        _selectedState = null;
        _selectedCity = null;
        _selectedLanguage = null;
      }
    } catch (error) {
      debugPrint('Error loading profile: $error');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (!widget.isLoggedIn || _isUploadingAvatar) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last.toLowerCase();
      final filePath = '${user.id}/avatar.$fileExt';

      await Supabase.instance.client.storage.from('avatars').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // Append timestamp query param so Flutter refreshes the cached image immediately
      final publicUrl =
          '${Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath)}?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _avatarUrl = publicUrl);
        widget.onProfileUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _getUserPlant() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final plantData = await Supabase.instance.client
          .from('user_plants')
          .select('plant_name, harvest_days')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activePlantName = plantData?['plant_name'] as String?;
          _activeHarvestDays = plantData?['harvest_days'] as int?;
        });
      }
    } catch (error) {
      debugPrint('Error loading user plant: $error');
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final updates = {
        'id': user.id,
        'username': _usernameController.text.trim(),
        'country': _selectedCountry,
        'state': _selectedState,
        'city': _selectedCity,
        'language': _selectedLanguage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('profiles').upsert(updates);

      if (mounted) {
        widget.onProfileUpdated?.call();
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

  void _openPlantSelectorDialog() {
    showDialog(
      context: context,
      builder: (_) => PlantSelectorDialog(
        currentPlantName: _activePlantName,
        onPlantSaved: () async {
          await _getUserPlant();
          widget.onPlantChanged?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isEditingAccount && widget.isLoggedIn) {
      return Container(
        color: _bgColor,
        child: const Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        color: _bgColor,
        child: Scrollbar(
          controller: _pageScrollController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(10),
          child: SingleChildScrollView(
            controller: _pageScrollController,
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
                  _buildNotificationPreferences(),
                  const SizedBox(height: 40),
                  if (widget.isLoggedIn) _buildFooterWithOvalButtons(),
                  if (!widget.isLoggedIn) _buildGuestFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
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
    String defaultName = 'User';
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && currentUser.email != null) {
      defaultName = currentUser.email!.split('@')[0];
    }

    final bool hasUploadedAvatar =
        widget.isLoggedIn && _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: widget.isLoggedIn ? _pickAndUploadAvatar : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: _isUploadingAvatar
                      ? CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          child: const CircularProgressIndicator(color: Colors.green),
                        )
                      : hasUploadedAvatar
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(_avatarUrl!),
                            )
                          : CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 70, color: Colors.grey.shade500),
                            ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.isLoggedIn ? _darkGreen : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            !widget.isLoggedIn
                ? 'Guest User'
                : (_hasProfileData ? _usernameController.text : defaultName),
            style: TextStyle(
              color: _hasProfileData ? _darkGreen : Colors.grey.shade400,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: _hasProfileData ? FontStyle.normal : FontStyle.italic,
            ),
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
            if (widget.isLoggedIn)
              GestureDetector(
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
                      hintText: 'Enter $label',
                      hintStyle: TextStyle(color: Colors.green.shade200),
                      contentPadding: const EdgeInsets.only(bottom: 4),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2)),
                    ),
                  )
                : Text(
                    !widget.isLoggedIn
                        ? '--'
                        : (controller.text.trim().isEmpty ? 'Not set' : controller.text),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: controller.text.trim().isEmpty ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: controller.text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRowDropdown(IconData icon, String label, String? currentValue, List<String> options, ValueChanged<String?> onChanged) {
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
                      hint: Text('Select $label', style: TextStyle(color: Colors.green.shade300, fontSize: 13)),
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
                    !widget.isLoggedIn
                        ? '--'
                        : (currentValue ?? 'Not set'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: currentValue == null ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: currentValue == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
          ),
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
            activeThumbColor: Colors.white,
            activeTrackColor: _darkGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFooter() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: true)));
            },
            icon: const Icon(Icons.login, color: Colors.white, size: 20),
            label: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              elevation: 4,
              shadowColor: const Color(0xFF064E3B).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: false)));
            },
            icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
            label: const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              elevation: 4,
              shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterWithOvalButtons() {
    final bool hasPlant = _activePlantName != null && _activePlantName!.trim().isNotEmpty;
    final String plantButtonLabel = hasPlant
        ? 'Change Plant ($_activePlantName${_activeHarvestDays != null ? ' • ${_activeHarvestDays}d' : ''})'
        : 'Add Experimental Plant';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _openPlantSelectorDialog,
            icon: Icon(Icons.eco_rounded, color: _darkGreen, size: 20),
            label: Text(
              plantButtonLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.bold),
            ),
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
          child: OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: true)));
              }
            },
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
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
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

class PlantSelectorDialog extends StatefulWidget {
  final String? currentPlantName;
  final VoidCallback onPlantSaved;

  const PlantSelectorDialog({
    super.key,
    this.currentPlantName,
    required this.onPlantSaved,
  });

  @override
  State<PlantSelectorDialog> createState() => _PlantSelectorDialogState();
}

class _PlantSelectorDialogState extends State<PlantSelectorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plantNameController = TextEditingController();

  CropPreset? _selectedPreset = kSuggestedCrops.first;
  bool _isCustom = false;
  int _harvestDays = 40;
  DateTime _plantedDate = DateTime.now();
  bool _isSaving = false;

  static const Color _darkGreen = Color(0xFF0A3B24);
  static const Color _accentGreen = Color(0xFF16A34A);
  static const Color _softBg = Color(0xFFEDF7F0);

  @override
  void initState() {
    super.initState();
    if (widget.currentPlantName != null && widget.currentPlantName!.trim().isNotEmpty) {
      final match = kSuggestedCrops.where(
        (c) => c.name.toLowerCase() == widget.currentPlantName!.trim().toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedPreset = match.first;
        _plantNameController.text = match.first.name;
        _harvestDays = match.first.suggestedDays;
      } else {
        _isCustom = true;
        _selectedPreset = null;
        _plantNameController.text = widget.currentPlantName!.trim();
      }
    } else {
      _plantNameController.text = _selectedPreset!.name;
    }
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    super.dispose();
  }

  void _selectPreset(CropPreset preset) {
    setState(() {
      _isCustom = false;
      _selectedPreset = preset;
      _plantNameController.text = preset.name;
      _harvestDays = preset.suggestedDays;
    });
  }

  void _selectCustom() {
    setState(() {
      _isCustom = true;
      _selectedPreset = null;
      _plantNameController.clear();
      _harvestDays = 35;
    });
  }

  Future<void> _pickPlantedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _darkGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _plantedDate = picked);
    }
  }

  Future<void> _savePlant() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first to configure a plant.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final plantName = _plantNameController.text.trim();
      final plantedIso = DateTime(
        _plantedDate.year,
        _plantedDate.month,
        _plantedDate.day,
      ).toIso8601String();

      await Supabase.instance.client.from('user_plants').upsert(
        {
          'user_id': user.id,
          'plant_name': plantName,
          'harvest_days': _harvestDays,
          'planted_date': plantedIso,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      if (!mounted) return;
      widget.onPlantSaved();
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _darkGreen,
          content: Text('Active plant set to $plantName ($_harvestDays-day cycle).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Failed to save plant: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUpdating =
        widget.currentPlantName != null && widget.currentPlantName!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _softBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.eco_rounded, color: _accentGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUpdating ? 'Change Experimental Plant' : 'Add Experimental Plant',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _darkGreen,
                          ),
                        ),
                        Text(
                          isUpdating
                              ? 'Current: ${widget.currentPlantName}'
                              : 'Select a crop to initialize AI & growth tracking',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Suggested Greenhouse Plants',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...kSuggestedCrops.map((crop) {
                    final selected = !_isCustom && _selectedPreset?.name == crop.name;
                    return ChoiceChip(
                      label: Text('${crop.name} (${crop.suggestedDays}d)'),
                      selected: selected,
                      selectedColor: _darkGreen,
                      backgroundColor: _softBg,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _darkGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: selected ? _darkGreen : Colors.green.shade200,
                        ),
                      ),
                      onSelected: (_) => _selectPreset(crop),
                    );
                  }),
                  ChoiceChip(
                    label: const Text('+ Custom Plant'),
                    selected: _isCustom,
                    selectedColor: _darkGreen,
                    backgroundColor: _softBg,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isCustom ? Colors.white : _darkGreen,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _isCustom ? _darkGreen : Colors.green.shade200,
                      ),
                    ),
                    onSelected: (_) => _selectCustom(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _plantNameController,
                readOnly: !_isCustom,
                decoration: InputDecoration(
                  labelText: 'Selected Plant Name',
                  hintText: 'e.g., Kale, Cherry Tomato, Choy Sum',
                  filled: true,
                  fillColor: _softBg,
                  prefixIcon: const Icon(Icons.local_florist_outlined, color: _darkGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a plant name' : null,
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _softBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Planting Cycle',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _darkGreen,
                          ),
                        ),
                        if (_selectedPreset != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Suggested: ${_selectedPreset!.suggestedDays} days',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _darkGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          icon: const Icon(Icons.remove, color: _darkGreen, size: 18),
                          onPressed: _harvestDays > 7
                              ? () => setState(() => _harvestDays--)
                              : null,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$_harvestDays Days',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkGreen,
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          icon: const Icon(Icons.add, color: _darkGreen, size: 18),
                          onPressed: _harvestDays < 180
                              ? () => setState(() => _harvestDays++)
                              : null,
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    InkWell(
                      onTap: _pickPlantedDate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Planting Start Date:',
                            style: TextStyle(fontSize: 12, color: _darkGreen),
                          ),
                          Row(
                            children: [
                              Text(
                                '${_plantedDate.day}/${_plantedDate.month}/${_plantedDate.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _accentGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_today, size: 14, color: _accentGreen),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedPreset != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPreset!.note,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _specTag('Temp: ${_selectedPreset!.tempRange}'),
                          _specTag('Moisture: ${_selectedPreset!.moistureRange}'),
                          _specTag('Humidity: ${_selectedPreset!.humidityRange}'),
                          _specTag('pH: ${_selectedPreset!.phRange}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (isUpdating) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Switching plants will reset your growth cycle counter based on the selected start date.',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _darkGreen,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _isSaving ? null : _savePlant,
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isUpdating ? 'Update Plant' : 'Start Growing'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specTag(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _darkGreen,
      ),
    );
  }
}