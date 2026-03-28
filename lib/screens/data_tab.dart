import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DataTab extends StatefulWidget {
  const DataTab({super.key});

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

  final Map<String, Color> _paramColors = {
    'Light': Colors.amber.shade600,
    'Humidity': Colors.blue.shade500,
    'pH Value': Colors.purple.shade400,
    'Soil Moisture': Colors.green.shade600,
    'Temperature': Colors.redAccent.shade400,
  };

  bool get _isAllSelected => _showLight && _showHumidity && _showPh && _showMoisture && _showTemp;

  void _toggleAll(bool? value) {
    if (value == null) return;
    setState(() {
      _showLight = value;
      _showHumidity = value;
      _showPh = value;
      _showMoisture = value;
      _showTemp = value;
    });
  }

  // Updated message format based on your request
  Widget _buildDynamicDateMessage() {
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
    List<String> active = [];
    if (_showLight) active.add('Light');
    if (_showHumidity) active.add('Humidity');
    if (_showPh) active.add('pH Value');
    if (_showMoisture) active.add('Soil Moisture');
    if (_showTemp) active.add('Temperature');
    return active;
  }

  List<Color> get _activeColors => _activeParams.map((p) => _paramColors[p]!).toList();

  @override
  void dispose() {
    _mainScroll.dispose();
    _tableVerticalScroll.dispose();
    _tableHorizontalScroll.dispose();
    super.dispose();
  }

Future<void> _pickDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), 
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            platform: TargetPlatform.windows, 
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600, 
              onPrimary: Colors.white,
              onSurface: const Color(0xFF333333), 
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Center(
            child: ConstrainedBox(
              // Increased maxHeight from 500 to 620 to prevent bottom clipping
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
              const SizedBox(height: 24),
              _buildParametersCard(),
              const SizedBox(height: 24),
              _buildFilterAndExportRow(),
              const SizedBox(height: 24),
              _buildChartCard(),
              const SizedBox(height: 24),
              _buildMetricLogTable(),
              const SizedBox(height: 40), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const SizedBox(
      width: double.infinity, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Text(
            'ECO-SYSTEM INTELLIGENCE',
            textAlign: TextAlign.center, 
            style: TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          SizedBox(height: 4),
          Text(
            'Historical Analysis', 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF022C22), height: 1.1),
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
                if (_customDateRange != null) ...[
                  const SizedBox(width: 8),
                  _buildDateChip(_selectedDateRange), 
                ]
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Report exported successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: Colors.green.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              )
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF065F46), 
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF064E3B).withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Export Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildDateChip(String label) {
    bool isSelected = _selectedDateRange == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateRange = label;
          if (label == 'Last 7 Days' || label == 'Last 30 Days') {
            _customDateRange = null; 
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.green.shade400 : Colors.green.shade100),
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
              const SizedBox(width: 6),
            ] else ...[
              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label, 
              style: TextStyle(
                color: isSelected ? Colors.green.shade800 : const Color(0xFF064E3B), 
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
            children: [
              const Text('Parameters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF022C22))),
              InkWell(
                onTap: () => _toggleAll(!_isAllSelected),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: _isAllSelected,
                        onChanged: _toggleAll,
                        activeColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
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
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF064E3B), fontSize: 14)),
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
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
                  const Text('Sensor Overlays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF022C22))),
                  Text('Aggregated telemetry over time', style: TextStyle(fontSize: 12, color: Colors.green.shade800.withOpacity(0.7))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _buildDynamicLegend(),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: MockChartPainter(activeColors: _activeColors),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _getDynamicXAxis(),
            ),
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100.withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Insight', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B), fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        _getDynamicAIInsight(),
                        style: TextStyle(color: Colors.green.shade800.withOpacity(0.8), fontSize: 12, height: 1.4),
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
    if (_activeParams.isEmpty) return "Select parameters above to generate AI analysis.";
    if (_activeParams.contains('Humidity') && _activeParams.contains('Temperature')) {
      return "High correlation detected between Temperature and Humidity over $_selectedDateRange. Recommend increasing ventilation during peak heat hours to prevent mold.";
    }
    if (_activeParams.contains('pH Value')) {
      return "pH levels showed slight fluctuations during $_selectedDateRange. Nutrient absorption remains optimal, but monitor dosing system closely.";
    }
    return "Trends for ${_activeParams.join(', ')} appear stable across the $_selectedDateRange period. No critical anomalies detected.";
  }

  // Generates data based on the selected dates
  List<Map<String, dynamic>> _getFilteredLogs() {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    if (_customDateRange != null) {
      start = _customDateRange!.start;
      // Force the end date to be the very last second of the selected day
      end = DateTime(
        _customDateRange!.end.year, 
        _customDateRange!.end.month, 
        _customDateRange!.end.day, 
        23, 59, 59
      );
    } else if (_selectedDateRange == 'Last 7 Days') {
      start = now.subtract(const Duration(days: 7));
      end = now;
    } else {
      start = now.subtract(const Duration(days: 30));
      end = now;
    }

    List<String> paramsToGenerate = _showAllLogSensors ? _paramColors.keys.toList() : _activeParams;
    if (paramsToGenerate.isEmpty) return [];

    List<Map<String, dynamic>> generatedLogs = [];
    
    // Calculate total minutes to distribute logs perfectly within the selected range
    int totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) totalMinutes = 1440; // Fallback to 24 hours

    for (int i = 0; i < 6; i++) {
      // Evenly space the data points across the exact selected timeframe
      int minutesToSubtract = (i * (totalMinutes / 5)).round();
      DateTime logDate = end.subtract(Duration(minutes: minutesToSubtract));
      
      String param = paramsToGenerate[i % paramsToGenerate.length];
      
      String val = '0';
      String status = 'Healthy';
      Color cBg = Colors.green.shade100;
      Color cTxt = Colors.green.shade800;
      Color cDot = Colors.green.shade600;

      if (param == 'Humidity') { val = '62.4%'; }
      else if (param == 'Soil Moisture') { val = '18.2%'; status = 'Stable'; cBg = const Color(0xFF064E3B); cTxt = Colors.white; cDot = Colors.greenAccent.shade400; }
      else if (param == 'Temperature') { val = '26.5°C'; }
      else if (param == 'Light') { val = '1.2k Lux'; status = 'Warning'; cBg = Colors.orange.shade100; cTxt = Colors.orange.shade900; cDot = Colors.orange; }
      else if (param == 'pH Value') { val = '6.8'; }

      generatedLogs.add({
        'date': DateFormat('MMM dd, yyyy').format(logDate),
        'time': DateFormat('HH:mm').format(logDate),
        'id': 'SN-882${i+1}',
        'param': param,
        'val': val,
        'status': status,
        'cBg': cBg,
        'cTxt': cTxt,
        'cDot': cDot
      });
    }
    return generatedLogs;
  }

  // --- METRIC LOG TABLE SECTION (Dynamic & Double Scrollbar) ---
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
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Metric Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF022C22))),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.calendar_month, color: Colors.green.shade700),
                      onPressed: _pickDateRange,
                      tooltip: 'Select Custom Date',
                    ),
                    InkWell(
                      onTap: () => setState(() => _showAllLogSensors = !_showAllLogSensors),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showAllLogSensors ? Colors.green.shade700 : Colors.green.shade50, 
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: Colors.green.shade100)
                        ),
                        child: Text(
                          'All Sensors', 
                          style: TextStyle(
                            color: _showAllLogSensors ? Colors.white : Colors.green.shade700, 
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
            padding: const EdgeInsets.only(bottom: 12.0, left: 24.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildDynamicDateMessage(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F5E9)), 
          
          SizedBox(
            height: 300, 
            width: double.infinity,
            // ⭐ FIX: Swapped the order. Horizontal Scroll is now on the OUTSIDE. ⭐
            child: Scrollbar(
              controller: _tableHorizontalScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _tableHorizontalScroll,
                scrollDirection: Axis.horizontal,
                // ⭐ FIX: Vertical Scroll is now on the INSIDE. ⭐
                child: Scrollbar(
                  controller: _tableVerticalScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableVerticalScroll,
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.green.shade50.withOpacity(0.5)),
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      dividerThickness: 1,
                      columns: const [
                        DataColumn(label: Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        DataColumn(label: Text('TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        DataColumn(label: Text('SENSOR ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        DataColumn(label: Text('PARAMETER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        DataColumn(label: Text('VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                      ],
                      rows: filteredLogs.isEmpty 
                        ? [DataRow(cells: List.generate(6, (index) => DataCell(Text(index == 3 ? 'No Data' : ''))))]
                        : filteredLogs.map((log) => _buildDataRow(
                            log['date'], log['time'], log['id'], log['param'], log['val'], log['status'], log['cBg'], log['cTxt'], log['cDot']
                          )).toList(),
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

  DataRow _buildDataRow(String date, String time, String id, String param, String val, String status, Color chipBg, Color chipText, Color dotColor) {
    return DataRow(
      cells: [
        DataCell(Text(date, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF064E3B), fontSize: 13))),
        DataCell(Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold))),
        DataCell(Text(id, style: TextStyle(color: Colors.green.shade700, fontSize: 13))),
        DataCell(Text(param, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF064E3B), fontSize: 13))),
        DataCell(Text(val, style: const TextStyle(color: Color(0xFF064E3B), fontSize: 13))),
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

class MockChartPainter extends CustomPainter {
  final List<Color> activeColors;

  MockChartPainter({required this.activeColors});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.green.shade50
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    for (int i = 0; i < activeColors.length; i++) {
      final paint = Paint()
        ..color = activeColors[i].withOpacity(0.8) 
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      double startY = size.height * (0.8 - (i * 0.15)).clamp(0.1, 0.9);
      double cp1Y = size.height * (0.2 + (i * 0.1)).clamp(0.1, 0.9);
      double cp2Y = size.height * (0.9 - (i * 0.2)).clamp(0.1, 0.9);
      double endY = size.height * (0.5 + (i * 0.1)).clamp(0.1, 0.9);

      path.moveTo(0, startY);
      path.quadraticBezierTo(size.width * 0.3, cp1Y, size.width * 0.6, size.height * 0.5);
      path.quadraticBezierTo(size.width * 0.8, cp2Y, size.width, endY);
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MockChartPainter oldDelegate) {
    return oldDelegate.activeColors != activeColors;
  }
}