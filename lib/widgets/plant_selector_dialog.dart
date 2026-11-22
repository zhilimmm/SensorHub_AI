import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const Color _darkGreen = Color(0xFF14452F);
  static const Color _accentGreen = Color(0xFF16A34A);
  static const Color _softBg = Color(0xFFF1F7F3);

  @override
  void initState() {
    super.initState();
    // Pre-select matching preset if the user already has an active plant
    if (widget.currentPlantName != null && widget.currentPlantName!.isNotEmpty) {
      final match = kSuggestedCrops.where(
        (c) => c.name.toLowerCase() == widget.currentPlantName!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedPreset = match.first;
        _plantNameController.text = match.first.name;
        _harvestDays = match.first.suggestedDays;
      } else {
        _isCustom = true;
        _selectedPreset = null;
        _plantNameController.text = widget.currentPlantName!;
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
      final supabase = Supabase.instance.client;
      final plantName = _plantNameController.text.trim();
      final plantedIso = DateTime(
        _plantedDate.year,
        _plantedDate.month,
        _plantedDate.day,
      ).toIso8601String();

      // Check if user already has an active plant row in `user_plants`
      final existing = await supabase
          .from('user_plants')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        // Current user changing experimental plant -> update existing record
        await supabase.from('user_plants').update({
          'plant_name': plantName,
          'harvest_days': _harvestDays,
          'planted_date': plantedIso,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', user.id);
      } else {
        // New user adding first plant -> insert new record
        await supabase.from('user_plants').insert({
          'user_id': user.id,
          'plant_name': plantName,
          'harvest_days': _harvestDays,
          'planted_date': plantedIso,
        });
      }

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
        widget.currentPlantName != null && widget.currentPlantName!.isNotEmpty;

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
              // Header
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
                          isUpdating ? 'Change Experimental Plant' : 'Add New Plant',
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

              // Suggested Crop Chips
              const Text(
                'Suggested Greenhouse Plants',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

              // Plant Name Input
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

              // Suggested Planting Duration Box
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
                    // Planting Start Date Selector
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

              // Optimal Conditions Preview (for suggested presets)
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

              // Reset Notice for Existing Users
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

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _darkGreen,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
                          borderRadius: BorderRadius.circular(30),
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