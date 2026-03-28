import 'package:flutter/material.dart';

class DataTab extends StatefulWidget {
  const DataTab({super.key});

  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> {
  // State variables
  bool _showLight = true;
  bool _showHumidity = true;
  bool _showPh = false;
  bool _showMoisture = true;
  bool _showTemp = false;
  String _selectedDateRange = 'Last 30 Days';

  // ⭐ NEW LOGIC: Computed property to check if ALL boxes are currently ticked ⭐
  bool get _isAllSelected => _showLight && _showHumidity && _showPh && _showMoisture && _showTemp;

  // ⭐ NEW LOGIC: Function to toggle all boxes at once ⭐
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
    );
  }

  // --- HEADER SECTION ---
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
            // 
            Text(
              'Historical Analysis', 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF022C22), height: 1.1),
            ),
          ],
        ),
      );
    }

  // --- UNIFIED TOOLBAR ROW ---
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
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {},
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

  // --- PARAMETERS SECTION ---
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
        // ⭐ FIX: Removed horizontal padding so the checkboxes align perfectly to the right ⭐
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

  // --- CHART SECTION ---
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
              Row(
                children: [
                  _buildChartLegendItem(Colors.green.shade600, 'HUMIDITY'),
                  const SizedBox(width: 12),
                  _buildChartLegendItem(Colors.green.shade900.withOpacity(0.4), 'MOISTURE'),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: MockChartPainter(),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('01 OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('07 OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('14 OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('21 OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('28 OCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
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
                        'Humidity peaks consistently correlate with night-cycle irrigation. Recommend reducing flow by 12% to prevent mold risk.',
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

  Widget _buildChartLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
      ],
    );
  }

  // --- METRIC LOG TABLE SECTION ---
  Widget _buildMetricLogTable() {
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
                      child: Text('All Sensors', style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.filter_list, color: Colors.green.shade400, size: 20),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F5E9)), 
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
              rows: [
                _buildDataRow('Oct 24, 2026', '14:32', 'SN-8821-X', 'Humidity', '62.4%', 'Healthy', Colors.green.shade100, Colors.green.shade800, Colors.green.shade600),
                _buildDataRow('Oct 24, 2026', '14:15', 'SN-8821-X', 'Soil Moisture', '18.2%', 'Stable', const Color(0xFF064E3B), Colors.white, Colors.greenAccent.shade400),
                _buildDataRow('Oct 24, 2026', '13:58', 'SN-8821-X', 'Temperature', '26.5°C', 'Healthy', Colors.green.shade100, Colors.green.shade800, Colors.green.shade600),
              ],
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

// --- MOCK CHART PAINTER ---
class MockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.green.shade50
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    final mainPaint = Paint()
      ..color = const Color(0xFF059669) 
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mainPath = Path();
    mainPath.moveTo(0, size.height * 0.7);
    mainPath.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.5);
    mainPath.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.4);
    canvas.drawPath(mainPath, mainPaint);

    final secondaryPaint = Paint()
      ..color = const Color(0xFF064E3B).withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryPath = Path();
    secondaryPath.moveTo(0, size.height * 0.9);
    secondaryPath.quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.6, size.height * 0.7);
    secondaryPath.quadraticBezierTo(size.width * 0.8, size.height * 0.9, size.width, size.height * 0.6);
    canvas.drawPath(secondaryPath, secondaryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}