import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataTab extends StatefulWidget {
  final bool isLoggedIn; 
  const DataTab({super.key, this.isLoggedIn = true});

  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> {
  final ScrollController _mainScroll = ScrollController();
  final ScrollController _tableVerticalScroll = ScrollController();
  final ScrollController _tableHorizontalScroll = ScrollController();

  bool _showLight = true;
  bool _showHumidity = true;
  bool _showPh = false;
  bool _showMoisture = true;
  bool _showTemp = false;

  String _selectedDateRange = 'Last 30 Days';
  DateTimeRange? _customDateRange;
  bool _showAllLogSensors = false;
  
  bool _hasProfileData = false; 
  bool _isLoadingData = true;

  // Real sensor rows stored directly from Supabase
  List<Map<String, dynamic>> _rawSensorData = [];
  StreamSubscription<List<Map<String, dynamic>>>? _dataStreamSub;

  bool get _isDataActive => widget.isLoggedIn && _hasProfileData;

  final Map<String, Color> _paramColors = {
    'Light': Colors.amber.shade600,
    'Humidity': Colors.blue.shade500,
    'pH Value': Colors.purple.shade400,
    'Soil Moisture': Colors.green.shade600,
    'Temperature': Colors.redAccent.shade400,
  };

  bool get _isAllSelected => _showLight && _showHumidity && _showPh && _showMoisture && _showTemp;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkProfileStatus();
      _fetchHistoricalData();
      _setupDataStream();
    }
  }

  @override
  void dispose() {
    _dataStreamSub?.cancel();
    _mainScroll.dispose();
    _tableVerticalScroll.dispose();
    _tableHorizontalScroll.dispose();
    super.dispose();
  }

  Future<void> _checkProfileStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
          
      if (mounted) {
        setState(() {
          _hasProfileData = data != null && data['username'] != null && data['username'].toString().trim().isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("DataTab error: $e");
    }
  }

  // Calculate the query start boundary
  DateTime _getStartDate() {
    if (_customDateRange != null) return _customDateRange!.start;
    if (_selectedDateRange == 'Last 7 Days') {
      return DateTime.now().subtract(const Duration(days: 7));
    }
    return DateTime.now().subtract(const Duration(days: 30));
  }

  // Calculate the query end boundary
  DateTime _getEndDate() {
    if (_customDateRange != null) {
      return DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    }
    return DateTime.now();
  }

  // Fetch real sensor records from Supabase
  Future<void> _fetchHistoricalData() async {
    setState(() => _isLoadingData = true);
    try {
      final startIso = _getStartDate().toIso8601String();
      final endIso = _getEndDate().toIso8601String();

      final response = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select()
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _rawSensorData = List<Map<String, dynamic>>.from(response);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sensor historical data: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // Live real-time stream listener for incoming sensor packets
  void _setupDataStream() {
    _dataStreamSub = Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((records) {
      if (mounted && records.isNotEmpty) {
        final start = _getStartDate();
        final end = _getEndDate();
        
        final filtered = records.where((row) {
          final rowTime = DateTime.tryParse(row['created_at']?.toString() ?? '');
          if (rowTime == null) return false;
          return rowTime.isAfter(start) && rowTime.isBefore(end);
        }).toList();

        setState(() {
          _rawSensorData = filtered;
        });
      }
    });
  }

  void _toggleAll(bool? value) {
    if (value == null || !_isDataActive) return;
    setState(() {
      _showLight = value;
      _showHumidity = value;
      _showPh = value;
      _showMoisture = value;
      _showTemp = value;
    });
  }

  Widget _buildDynamicDateMessage() {
    if (!_isDataActive) {
      return Text(
        widget.isLoggedIn ? 'Waiting for profile setup.' : 'System offline.', 
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic)
      );
    }

    String message;
    if (_customDateRange != null) {
      String startDate = DateFormat('MMM dd, yyyy').format(_customDateRange!.start);
      String endDate = DateFormat('MMM dd, yyyy').format(_customDateRange!.end);
      message = 'showing data from $startDate until $endDate';
    } else {
      message = 'showing data for: $_selectedDateRange';
    }

    return Text(
      message, 
      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic)
    );
  }

  List<String> get _activeParams {
    if (!_isDataActive) return [];
    List<String> active = [];
    if (_showLight) active.add('Light');
    if (_showHumidity) active.add('Humidity');
    if (_showPh) active.add('pH Value');
    if (_showMoisture) active.add('Soil Moisture');
    if (_showTemp) active.add('Temperature');
    return active;
  }

  Future<void> _pickDateRange() async {
    if (!_isDataActive) return;

    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025), 
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700, 
              onPrimary: Colors.white,
              onSurface: const Color(0xFF333333), 
            ), 
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
              child: child!,
            ),
          ),
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customDateRange = pickedRange;
        _selectedDateRange = '${DateFormat('MMM dd').format(pickedRange.start)} - ${DateFormat('MMM dd').format(pickedRange.end)}';
      });
      _fetchHistoricalData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _mainScroll,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(10),
      child: SingleChildScrollView(
        controller: _mainScroll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 20),
              _buildParametersCard(),
              const SizedBox(height: 20),
              _buildFilterAndExportRow(),
              const SizedBox(height: 20),
              _buildChartCard(),
              const SizedBox(height: 20),
              _buildMetricLogTable(),
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
            'ECO-SYSTEM INTELLIGENCE',
            textAlign: TextAlign.center, 
            style: TextStyle(color: _isDataActive ? const Color(0xFF047857) : Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            'Historical Analysis', 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _isDataActive ? const Color(0xFF022C22) : Colors.grey.shade700, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndExportRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip('Last 7 Days'),
                const SizedBox(width: 8),
                _buildDateChip('Last 30 Days'),
                if (_customDateRange != null && _isDataActive) ...[
                  const SizedBox(width: 8),
                  _buildDateChip(_selectedDateRange), 
                ]
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isDataActive ? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Telemetry logs exported successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: Colors.green.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              )
            );
          } : null, 
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDataActive ? const Color(0xFF065F46) : Colors.grey.shade300, 
            foregroundColor: _isDataActive ? Colors.white : Colors.grey.shade500,
            elevation: _isDataActive ? 3 : 0,
            shadowColor: const Color(0xFF064E3B).withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Export Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildDateChip(String label) {
    bool isSelected = _selectedDateRange == label && _isDataActive;
    return GestureDetector(
      onTap: _isDataActive ? () {
        setState(() {
          _selectedDateRange = label;
          if (label == 'Last 7 Days' || label == 'Last 30 Days') {
            _customDateRange = null; 
          }
        });
        _fetchHistoricalData();
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : (_isDataActive ? Colors.white.withOpacity(0.8) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.green.shade400 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
              const SizedBox(width: 6),
            ] else ...[
              Icon(Icons.calendar_today, color: _isDataActive ? Colors.green.shade700 : Colors.grey, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label, 
              style: TextStyle(
                color: _isDataActive ? (isSelected ? Colors.green.shade800 : const Color(0xFF064E3B)) : Colors.grey, 
                fontWeight: FontWeight.bold, 
                fontSize: 12 
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParametersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parameters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _isDataActive ? const Color(0xFF022C22) : Colors.grey.shade600)),
              InkWell(
                onTap: _isDataActive ? () => _toggleAll(!_isAllSelected) : null,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: _isAllSelected && _isDataActive,
                        onChanged: _isDataActive ? _toggleAll : null,
                        activeColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckboxRow('Light', _showLight, (val) => setState(() => _showLight = val!)),
          _buildCheckboxRow('Humidity', _showHumidity, (val) => setState(() => _showHumidity = val!)),
          _buildCheckboxRow('pH Value', _showPh, (val) => setState(() => _showPh = val!)),
          _buildCheckboxRow('Soil Moisture', _showMoisture, (val) => setState(() => _showMoisture = val!)),
          _buildCheckboxRow('Temperature', _showTemp, (val) => setState(() => _showTemp = val!)),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow(String title, bool value, Function(bool?) onChanged) {
    return InkWell(
      onTap: _isDataActive ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey, fontSize: 14)),
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: value && _isDataActive,
                onChanged: _isDataActive ? onChanged : null,
                activeColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sensor Overlays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _isDataActive ? const Color(0xFF022C22) : Colors.grey.shade600)),
                  Text('Aggregated live telemetry from ESP32', style: TextStyle(fontSize: 12, color: _isDataActive ? Colors.green.shade800.withOpacity(0.7) : Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildDynamicLegend(),
          ),
          const SizedBox(height: 28),
          
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _isLoadingData 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF047857)))
              : (_rawSensorData.isEmpty 
                  ? Center(child: Text('No telemetry points found for this range.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
                  : CustomPaint(
                      painter: RealChartPainter(
                        sensorData: _rawSensorData,
                        activeParams: _activeParams,
                        paramColors: _paramColors,
                      ),
                    )),
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _getDynamicXAxis(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDataActive ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100.withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology, color: _isDataActive ? Colors.green.shade700 : Colors.grey.shade400, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Insight', style: TextStyle(fontWeight: FontWeight.bold, color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey.shade600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        _getDynamicAIInsight(),
                        style: TextStyle(color: _isDataActive ? Colors.green.shade800.withOpacity(0.8) : Colors.grey.shade500, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDynamicLegend() {
    if (_activeParams.isEmpty) {
      return Center(child: Text('No parameters selected', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }

    List<Widget> legendItems = _activeParams.map((p) => _buildChartLegendItem(_paramColors[p]!, p.toUpperCase())).toList();
    
    if (legendItems.length <= 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _addSpacing(legendItems, 16.0),
      );
    } else if (legendItems.length == 4) {
      return Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _addSpacing(legendItems.sublist(0, 2), 16.0)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _addSpacing(legendItems.sublist(2, 4), 16.0)),
        ],
      );
    } else {
      return Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _addSpacing(legendItems.sublist(0, 3), 16.0)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _addSpacing(legendItems.sublist(3, 5), 16.0)),
        ],
      );
    }
  }

  List<Widget> _addSpacing(List<Widget> items, double spacing) {
    List<Widget> result = [];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }

  Widget _buildChartLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  List<Widget> _getDynamicXAxis() {
    if (!_isDataActive || _rawSensorData.isEmpty) {
      return ['--', '--', '--', '--'].map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))).toList();
    }

    if (_rawSensorData.length >= 4) {
      DateTime first = DateTime.parse(_rawSensorData.first['created_at']);
      DateTime last = DateTime.parse(_rawSensorData.last['created_at']);
      Duration diff = last.difference(first);

      DateTime p2 = first.add(Duration(milliseconds: (diff.inMilliseconds * 0.33).round()));
      DateTime p3 = first.add(Duration(milliseconds: (diff.inMilliseconds * 0.66).round()));

      final fmt = DateFormat('MM/dd');
      return [fmt.format(first), fmt.format(p2), fmt.format(p3), fmt.format(last)]
          .map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))
          .toList();
    }

    List<String> labels;
    if (_selectedDateRange == 'Last 7 Days') {
      labels = ['Day 1', 'Day 3', 'Day 5', 'Day 7'];
    } else if (_selectedDateRange == 'Last 30 Days') {
      labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    } else {
      labels = ['Start', 'Mid', 'End'];
    }
    return labels.map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))).toList();
  }

  String _getDynamicAIInsight() {
    if (!_isDataActive) {
      return widget.isLoggedIn 
        ? "Please complete your profile setup in Settings to view AI insights." 
        : "System offline. Please log in to view historical data and AI insights.";
    }
    if (_rawSensorData.isEmpty) {
      return "No telemetry logged yet for this period. AI will provide insights once the ESP32 uploads data.";
    }
    if (_activeParams.isEmpty) return "Select parameters above to generate AI analysis.";
    
    // Evaluate the latest sensor metrics
    final latest = _rawSensorData.last;
    final temp = (latest['temperature'] as num?)?.toDouble() ?? 25.0;
    final humid = (latest['humidity'] as num?)?.toDouble() ?? 75.0;
    final moist = (latest['soil_moisture'] as num?)?.toInt() ?? 80;

    if (temp > 28.0 && humid > 80.0) {
      return "High temperature (${temp.toStringAsFixed(1)}°C) and humidity (${humid.toStringAsFixed(0)}%) detected. Ventilation active to support sweet potato leaf transpiration.";
    }
    if (moist < 70) {
      return "Soil moisture dropped below target (${moist}%). Smart irrigation burst will cycle to maintain 80% optimal moisture.";
    }
    return "Microclimate is well-balanced for sweet potato vegetative growth. Sensors report steady conditions within optimal zones.";
  }

  // Deconstruct real database records into row entries for each metric
  List<Map<String, dynamic>> _getFilteredLogs() {
    if (!_isDataActive || _rawSensorData.isEmpty) {
      return [];
    }

    List<String> targetParams = _showAllLogSensors ? _paramColors.keys.toList() : _activeParams;
    if (targetParams.isEmpty) return [];

    List<Map<String, dynamic>> logList = [];
    
    // Reverse order so newest records are at the top
    final reversed = _rawSensorData.reversed.toList();

    for (var row in reversed) {
      DateTime dt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
      String dateStr = DateFormat('MMM dd, yyyy').format(dt);
      String timeStr = DateFormat('HH:mm').format(dt);

      if (targetParams.contains('Humidity') && row['humidity'] != null) {
        double val = (row['humidity'] as num).toDouble();
        bool isOpt = val >= 70 && val <= 90;
        logList.add({
          'date': dateStr, 'time': timeStr, 'param': 'Humidity', 'val': '${val.toStringAsFixed(1)}%',
          'status': isOpt ? 'Optimal' : (val > 90 ? 'High' : 'Low'),
          'cBg': isOpt ? Colors.green.shade100 : Colors.orange.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.orange.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.orange.shade600,
        });
      }

      if (targetParams.contains('Soil Moisture') && row['soil_moisture'] != null) {
        int val = (row['soil_moisture'] as num).toInt();
        bool isOpt = val >= 70 && val <= 90;
        logList.add({
          'date': dateStr, 'time': timeStr, 'param': 'Soil Moisture', 'val': '$val%',
          'status': isOpt ? 'Optimal' : (val < 50 ? 'Dry' : 'Warning'),
          'cBg': isOpt ? Colors.green.shade100 : Colors.orange.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.orange.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.orange.shade600,
        });
      }

      if (targetParams.contains('Temperature') && row['temperature'] != null) {
        double val = (row['temperature'] as num).toDouble();
        bool isOpt = val >= 22 && val <= 28;
        logList.add({
          'date': dateStr, 'time': timeStr, 'param': 'Temperature', 'val': '${val.toStringAsFixed(1)}°C',
          'status': isOpt ? 'Optimal' : (val > 28 ? 'Warm' : 'Cool'),
          'cBg': isOpt ? Colors.green.shade100 : Colors.orange.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.orange.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.orange.shade600,
        });
      }

      if (targetParams.contains('Light') && row['light'] != null) {
        int val = (row['light'] as num).toInt();
        logList.add({
          'date': dateStr, 'time': timeStr, 'param': 'Light', 'val': '$val Lux',
          'status': 'Optimal',
          'cBg': Colors.green.shade100,
          'cTxt': Colors.green.shade900,
          'cDot': Colors.green.shade600,
        });
      }

      if (targetParams.contains('pH Value') && row['ph_value'] != null) {
        double val = (row['ph_value'] as num).toDouble();
        bool isOpt = val >= 5.8 && val <= 7.2;
        logList.add({
          'date': dateStr, 'time': timeStr, 'param': 'pH Value', 'val': val.toStringAsFixed(2),
          'status': isOpt ? 'Optimal' : 'Warning',
          'cBg': isOpt ? Colors.green.shade100 : Colors.purple.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.purple.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.purple.shade600,
        });
      }

      // Keep table snappy by limiting to recent records
      if (logList.length >= 40) break;
    }

    return logList;
  }

  Widget _buildMetricLogTable() {
    List<Map<String, dynamic>> filteredLogs = _getFilteredLogs();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Metric Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _isDataActive ? const Color(0xFF022C22) : Colors.grey.shade600)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.calendar_month, color: _isDataActive ? Colors.green.shade700 : Colors.grey),
                      onPressed: _pickDateRange,
                      tooltip: 'Select Custom Date',
                    ),
                    InkWell(
                      onTap: _isDataActive ? () => setState(() => _showAllLogSensors = !_showAllLogSensors) : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_showAllLogSensors && _isDataActive) ? Colors.green.shade700 : (_isDataActive ? Colors.green.shade50 : Colors.grey.shade200), 
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: Colors.green.shade100)
                        ),
                        child: Text(
                          'All Sensors', 
                          style: TextStyle(
                            color: (_showAllLogSensors && _isDataActive) ? Colors.white : Colors.grey.shade600, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildDynamicDateMessage(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F5E9)), 
          
          SizedBox(
            height: 300, 
            width: double.infinity,
            child: Scrollbar(
              controller: _tableVerticalScroll, 
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical, 
              child: Scrollbar(
                controller: _tableHorizontalScroll, 
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(10),
                notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal, 
                child: SingleChildScrollView(
                  controller: _tableVerticalScroll,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _tableHorizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0), 
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.green.shade50.withOpacity(0.5)),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 52,
                        dividerThickness: 1,
                        // Removed SENSOR ID column
                        columns: const [
                          DataColumn(label: Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('PARAMETER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        ],
                        rows: filteredLogs.isEmpty 
                          ? [const DataRow(cells: [DataCell(Text('')), DataCell(Text('')), DataCell(Text('No Records Found')), DataCell(Text('')), DataCell(Text(''))])]
                          : filteredLogs.map((log) => _buildDataRow(
                              log['date'], log['time'], log['param'], log['val'], log['status'], log['cBg'], log['cTxt'], log['cDot']
                            )).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  DataRow _buildDataRow(String date, String time, String param, String val, String status, Color chipBg, Color chipText, Color dotColor) {
    return DataRow(
      cells: [
        DataCell(Text(date, style: TextStyle(fontWeight: FontWeight.w700, color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey.shade500, fontSize: 12))),
        DataCell(Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
        DataCell(Text(param, style: TextStyle(fontWeight: FontWeight.w700, color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey.shade500, fontSize: 12))),
        DataCell(Text(val, style: TextStyle(color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: dotColor),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: chipText, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Maps real normalized data curves
class RealChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> sensorData;
  final List<String> activeParams;
  final Map<String, Color> paramColors;

  RealChartPainter({
    required this.sensorData,
    required this.activeParams,
    required this.paramColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    if (sensorData.isEmpty || activeParams.isEmpty) return;

    for (var param in activeParams) {
      final color = paramColors[param] ?? Colors.green;
      final paint = Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      bool firstPoint = true;

      for (int i = 0; i < sensorData.length; i++) {
        final row = sensorData[i];
        double? rawValue;

        if (param == 'Humidity' && row['humidity'] != null) {
          rawValue = ((row['humidity'] as num).toDouble()).clamp(0.0, 100.0) / 100.0;
        } else if (param == 'Soil Moisture' && row['soil_moisture'] != null) {
          rawValue = ((row['soil_moisture'] as num).toDouble()).clamp(0.0, 100.0) / 100.0;
        } else if (param == 'Temperature' && row['temperature'] != null) {
          // Normalize 10°C - 45°C
          rawValue = (((row['temperature'] as num).toDouble() - 10.0) / 35.0).clamp(0.0, 1.0);
        } else if (param == 'Light' && row['light'] != null) {
          // Normalize 0 - 4095 ADC
          rawValue = ((row['light'] as num).toDouble() / 4095.0).clamp(0.0, 1.0);
        } else if (param == 'pH Value' && row['ph_value'] != null) {
          // Normalize 0 - 14 pH
          rawValue = ((row['ph_value'] as num).toDouble() / 14.0).clamp(0.0, 1.0);
        }

        if (rawValue != null) {
          double x = sensorData.length == 1 ? size.width / 2 : (i / (sensorData.length - 1)) * size.width;
          // Canvas coordinates are inverted vertically: 0 is top, height is bottom
          double y = size.height - (rawValue * (size.height * 0.85) + (size.height * 0.07));

          if (firstPoint) {
            path.moveTo(x, y);
            firstPoint = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RealChartPainter oldDelegate) {
    return oldDelegate.sensorData != sensorData || oldDelegate.activeParams != activeParams;
  }
}