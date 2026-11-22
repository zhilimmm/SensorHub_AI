import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  final GlobalKey _chartKey = GlobalKey();

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
  bool _isExporting = false;

  // Dynamic AI Trend Insight state
  String _aiTrendInsight = 'Analyzing sensor trends...';
  bool _isAnalyzingTrend = false;

  // Real sensor rows stored directly from Supabase (isolated by user_id)
  List _rawSensorData = [];
  StreamSubscription? _dataStreamSub;

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
      _checkProfileStatus().then((_) {
        _fetchHistoricalData();
        _setupDataStream();
      });
    } else {
      _isLoadingData = false;
    }
  }

  @override
  void didUpdateWidget(covariant DataTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && !oldWidget.isLoggedIn) {
      _checkProfileStatus().then((_) {
        _fetchHistoricalData();
        _setupDataStream();
      });
    } else if (!widget.isLoggedIn && oldWidget.isLoggedIn) {
      _dataStreamSub?.cancel();
      setState(() {
        _hasProfileData = false;
        _rawSensorData = [];
        _isLoadingData = false;
      });
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

  // Maps UI checkboxes to Python FastAPI sensor keys
  List _getSelectedApiKeys() {
    final keys = [];
    if (_showLight) keys.add('light');
    if (_showHumidity) keys.add('humidity');
    if (_showPh) keys.add('ph_value');
    if (_showMoisture) keys.add('soil_moisture');
    if (_showTemp) keys.add('temperature');
    return keys;
  }

  // Calls FastAPI /api/analyze-trend to get scenario-based insight
  Future<void> _fetchTrendInsight() async {
    if (!mounted) return;

    if (!_isDataActive) {
      setState(() {
        _aiTrendInsight = widget.isLoggedIn
            ? "Please complete your profile setup in Settings to view AI insights."
            : "System offline. Please log in to view historical data and AI insights.";
        _isAnalyzingTrend = false;
      });
      return;
    }

    if (_rawSensorData.isEmpty) {
      setState(() {
        _aiTrendInsight = "No sensor data in database for this account yet. AI insights will appear once your ESP32 uploads telemetry.";
        _isAnalyzingTrend = false;
      });
      return;
    }

    final selectedKeys = _getSelectedApiKeys();
    if (selectedKeys.isEmpty) {
      setState(() {
        _aiTrendInsight = "Select parameters above to generate AI analysis.";
        _isAnalyzingTrend = false;
      });
      return;
    }

    setState(() => _isAnalyzingTrend = true);

    try {
      final cleanPoints = _rawSensorData.map((row) {
        final point = {};
        for (final key in selectedKeys) {
          if (row[key] != null && row[key] is num) {
            point[key] = (row[key] as num).toDouble();
          }
        }
        return point;
      }).where((pt) => pt.isNotEmpty).toList();

      final url = Uri.parse('https://sensorhub-ai-backend.onrender.com/api/analyze-trend');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'selected_sensors': selectedKeys,
          'data_points': cleanPoints,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _aiTrendInsight = decoded['insight'] ?? 'Unable to generate insight.';
            _isAnalyzingTrend = false;
          });
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Trend Insight API Error: $e");
      if (mounted) {
        setState(() {
          _aiTrendInsight = "Could not reach AI backend. Make sure your FastAPI server is running.";
          _isAnalyzingTrend = false;
        });
      }
    }
  }

  // Exports a PDF report with the selected parameters' chart, AI Insight, and logs
  Future<void> _exportPdfReport() async {
    if (!_isDataActive || _rawSensorData.isEmpty || _activeParams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one parameter with data to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      ui.Image? chartImage;
      if (boundary != null) {
        chartImage = await boundary.toImage(pixelRatio: 3.0);
      }
      final byteData = await chartImage?.toByteData(format: ui.ImageByteFormat.png);
      final chartBytes = byteData?.buffer.asUint8List();

      final pdf = pw.Document();
      final filteredLogs = _getFilteredLogs(forceSelectedOnly: true);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              pw.Text(
                'SensorHub AI - Telemetry Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date Range: $_selectedDateRange  |  Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Text(
                'Selected Parameters: ${_activeParams.join(', ')}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
              ),
              pw.Divider(height: 20),
              if (chartBytes != null) ...[
                pw.Text('Sensor Overlay Chart', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Image(pw.MemoryImage(chartBytes), fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 16),
              ],
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AI Trend Insight', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.SizedBox(height: 4),
                    pw.Text(_aiTrendInsight, style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Metric Log (Selected Parameters)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Date', 'Time', 'Parameter', 'Value', 'Status'],
                data: filteredLogs.map((log) => [
                  log['date'].toString(),
                  log['time'].toString(),
                  log['param'].toString(),
                  log['val'].toString(),
                  log['status'].toString(),
                ]).toList(),
              ),
            ];
          },
        ),
      );

      final userEmail = Supabase.instance.client.auth.currentUser?.email;
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('No registered email found for this account.');
      }

      final pdfBytes = await pdf.save();
      final pdfBase64 = base64Encode(pdfBytes);
      final fileName = 'SensorHub_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      final emailUrl = Uri.parse('https://sensorhub-ai-backend.onrender.com/api/email-report');
      final emailRes = await http.post(
        emailUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipient_email': userEmail,
          'filename': fileName,
          'pdf_base64': pdfBase64,
        }),
      );

      if (emailRes.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report emailed to $userEmail!'),
              backgroundColor: Colors.green.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Email server error: ${emailRes.body}');
      }
    } catch (e) {
      debugPrint('PDF Export Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  DateTime _getStartDate() {
    if (_customDateRange != null) return _customDateRange!.start;
    if (_selectedDateRange == 'Last 7 Days') {
      return DateTime.now().subtract(const Duration(days: 7));
    }
    return DateTime.now().subtract(const Duration(days: 30));
  }

  DateTime _getEndDate() {
    if (_customDateRange != null) {
      return DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    }
    return DateTime.now();
  }

  // Fetch real sensor records from Supabase filtered by `user_id`
  Future<void> _fetchHistoricalData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingData = false);
      return;
    }

    setState(() => _isLoadingData = true);
    try {
      final startIso = _getStartDate().toIso8601String();
      final endIso = _getEndDate().toIso8601String();

      final response = await Supabase.instance.client
          .from('sweet_potato_leave_data')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _rawSensorData = List.from(response);
          _isLoadingData = false;
        });
        _fetchTrendInsight();
      }
    } catch (e) {
      debugPrint("Error fetching sensor historical data: $e");
      if (mounted) {
        setState(() {
          _rawSensorData = [];
          _isLoadingData = false;
        });
        _fetchTrendInsight();
      }
    }
  }

  // Live real-time stream listener isolated by `user_id`
  void _setupDataStream() {
    _dataStreamSub?.cancel();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _dataStreamSub = Supabase.instance.client
        .from('sweet_potato_leave_data')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: true)
        .listen((records) {
      if (!mounted) return;
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
      _fetchTrendInsight();
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
    _fetchTrendInsight();
  }

  Widget _buildDynamicDateMessage() {
    if (!_isDataActive) {
      return Text(
        widget.isLoggedIn ? 'Waiting for profile setup.' : 'System offline.',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
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
      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
    );
  }

  List get _activeParams {
    if (!_isDataActive) return [];
    final active = [];
    if (_showLight) active.add('Light');
    if (_showHumidity) active.add('Humidity');
    if (_showPh) active.add('pH Value');
    if (_showMoisture) active.add('Soil Moisture');
    if (_showTemp) active.add('Temperature');
    return active;
  }

  Future<void> _pickDateRange() async {
    if (!_isDataActive) return;

    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _CustomDateRangeDialog(
        initialRange: _customDateRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      ),
    );

    if (pickedRange != null) {
      setState(() {
        _customDateRange = pickedRange;
        _selectedDateRange =
            '${DateFormat('MMM dd').format(pickedRange.start)} - ${DateFormat('MMM dd').format(pickedRange.end)}';
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
    final bool canExport = _isDataActive && _rawSensorData.isNotEmpty && !_isExporting;
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
          onPressed: canExport ? _exportPdfReport : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canExport ? const Color(0xFF065F46) : Colors.grey.shade300,
            foregroundColor: canExport ? Colors.white : Colors.grey.shade500,
            elevation: canExport ? 3 : 0,
            shadowColor: const Color(0xFF064E3B).withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Export Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildDateChip(String label) {
    bool isSelected = _selectedDateRange == label && _isDataActive;
    return GestureDetector(
      onTap: _isDataActive
          ? () {
              setState(() {
                _selectedDateRange = label;
                if (label == 'Last 7 Days' || label == 'Last 30 Days') {
                  _customDateRange = null;
                }
              });
              _fetchHistoricalData();
            }
          : null,
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
                fontSize: 12,
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
          _buildCheckboxRow('Light', _showLight, (val) {
            setState(() => _showLight = val!);
            _fetchTrendInsight();
          }),
          _buildCheckboxRow('Humidity', _showHumidity, (val) {
            setState(() => _showHumidity = val!);
            _fetchTrendInsight();
          }),
          _buildCheckboxRow('pH Value', _showPh, (val) {
            setState(() => _showPh = val!);
            _fetchTrendInsight();
          }),
          _buildCheckboxRow('Soil Moisture', _showMoisture, (val) {
            setState(() => _showMoisture = val!);
            _fetchTrendInsight();
          }),
          _buildCheckboxRow('Temperature', _showTemp, (val) {
            setState(() => _showTemp = val!);
            _fetchTrendInsight();
          }),
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
          RepaintBoundary(
            key: _chartKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
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
                            ? Center(
                                child: Text(
                                  'No sensor data in database for this account yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              )
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
                    child: _buildDynamicXAxisRow(),
                  ),
                ],
              ),
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
                      Row(
                        children: [
                          Text('AI Insight', style: TextStyle(fontWeight: FontWeight.bold, color: _isDataActive ? const Color(0xFF064E3B) : Colors.grey.shade600, fontSize: 14)),
                          if (_isAnalyzingTrend) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green.shade700),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiTrendInsight,
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

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14.0,
      runSpacing: 8.0,
      children: _activeParams
          .map((p) => _buildChartLegendItem(_paramColors[p]!, p.toString().toUpperCase()))
          .toList(),
    );
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

  Widget _buildDynamicXAxisRow() {
    if (!_isDataActive || _rawSensorData.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ['--', '--', '--', '--']
            .map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))
            .toList(),
      );
    }

    if (_rawSensorData.length >= 4) {
      DateTime first = DateTime.parse(_rawSensorData.first['created_at']);
      DateTime last = DateTime.parse(_rawSensorData.last['created_at']);
      Duration diff = last.difference(first);

      DateTime p2 = first.add(Duration(milliseconds: (diff.inMilliseconds * 0.33).round()));
      DateTime p3 = first.add(Duration(milliseconds: (diff.inMilliseconds * 0.66).round()));

      final fmt = DateFormat('MM/dd');
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [fmt.format(first), fmt.format(p2), fmt.format(p3), fmt.format(last)]
            .map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))
            .toList(),
      );
    }

    final labels = _selectedDateRange == 'Last 7 Days'
        ? ['Day 1', 'Day 3', 'Day 5', 'Day 7']
        : (_selectedDateRange == 'Last 30 Days'
            ? ['Week 1', 'Week 2', 'Week 3', 'Week 4']
            : ['Start', 'Mid', 'End']);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((l) => Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))
          .toList(),
    );
  }

  List _getFilteredLogs({bool forceSelectedOnly = false}) {
    if (!_isDataActive || _rawSensorData.isEmpty) {
      return [];
    }

    final targetParams = (!forceSelectedOnly && _showAllLogSensors) ? _paramColors.keys.toList() : _activeParams;
    if (targetParams.isEmpty) return [];

    final logList = [];
    final reversed = _rawSensorData.reversed.toList();

    for (var row in reversed) {
      DateTime dt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
      String dateStr = DateFormat('MMM dd, yyyy').format(dt);
      String timeStr = DateFormat('HH:mm').format(dt);

      if (targetParams.contains('Humidity') && row['humidity'] != null) {
        double val = (row['humidity'] as num).toDouble();
        bool isOpt = val >= 70 && val <= 90;
        logList.add({
          'date': dateStr,
          'time': timeStr,
          'param': 'Humidity',
          'val': '${val.toStringAsFixed(1)}%',
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
          'date': dateStr,
          'time': timeStr,
          'param': 'Soil Moisture',
          'val': '$val%',
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
          'date': dateStr,
          'time': timeStr,
          'param': 'Temperature',
          'val': '${val.toStringAsFixed(1)}°C',
          'status': isOpt ? 'Optimal' : (val > 28 ? 'Warm' : 'Cool'),
          'cBg': isOpt ? Colors.green.shade100 : Colors.orange.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.orange.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.orange.shade600,
        });
      }

      if (targetParams.contains('Light') && row['light'] != null) {
        int val = (row['light'] as num).toInt();
        logList.add({
          'date': dateStr,
          'time': timeStr,
          'param': 'Light',
          'val': '$val Lux',
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
          'date': dateStr,
          'time': timeStr,
          'param': 'pH Value',
          'val': val.toStringAsFixed(2),
          'status': isOpt ? 'Optimal' : 'Warning',
          'cBg': isOpt ? Colors.green.shade100 : Colors.purple.shade100,
          'cTxt': isOpt ? Colors.green.shade900 : Colors.purple.shade900,
          'cDot': isOpt ? Colors.green.shade600 : Colors.purple.shade600,
        });
      }

      if (logList.length >= 40) break;
    }

    return logList;
  }

  Widget _buildMetricLogTable() {
    final filteredLogs = _getFilteredLogs();

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
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          'All Sensors',
                          style: TextStyle(
                            color: (_showAllLogSensors && _isDataActive) ? Colors.white : Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
                        columns: const [
                          DataColumn(label: Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('PARAMETER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1))),
                        ],
                        rows: filteredLogs.isEmpty
                            ? [const DataRow(cells: [DataCell(Text('')), DataCell(Text('')), DataCell(Text('No Records Found')), DataCell(Text('')), DataCell(Text(''))])]
                            : filteredLogs
                                .map((log) => _buildDataRow(log['date'], log['time'], log['param'], log['val'], log['status'], log['cBg'], log['cTxt'], log['cDot']))
                                .toList(),
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

class RealChartPainter extends CustomPainter {
  final List sensorData;
  final List activeParams;
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
          rawValue = (((row['temperature'] as num).toDouble() - 10.0) / 35.0).clamp(0.0, 1.0);
        } else if (param == 'Light' && row['light'] != null) {
          rawValue = ((row['light'] as num).toDouble() / 4095.0).clamp(0.0, 1.0);
        } else if (param == 'pH Value' && row['ph_value'] != null) {
          rawValue = ((row['ph_value'] as num).toDouble() / 14.0).clamp(0.0, 1.0);
        }

        if (rawValue != null) {
          double x = sensorData.length == 1 ? size.width / 2 : (i / (sensorData.length - 1)) * size.width;
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

class _CustomDateRangeDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  const _CustomDateRangeDialog({required this.initialRange});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _focusedMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  final Color _primaryGreen = const Color(0xFF065F46);
  final Color _softGreen = const Color(0xFFD1FAE5);

  @override
  void initState() {
    super.initState();
    _startDate = _stripTime(widget.initialRange.start);
    _endDate = _stripTime(widget.initialRange.end);
    _focusedMonth = DateTime(_endDate!.year, _endDate!.month);
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDayTap(DateTime day) {
    final tapped = _stripTime(day);
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = tapped;
        _endDate = null;
      } else if (tapped.isBefore(_startDate!)) {
        _endDate = _startDate;
        _startDate = tapped;
      } else {
        _endDate = tapped;
      }
    });
  }

  List _buildCalendarDays() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final int leadingDays = firstDayOfMonth.weekday % 7;
    final startGrid = firstDayOfMonth.subtract(Duration(days: leadingDays));

    return List.generate(42, (index) => startGrid.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays();
    final today = _stripTime(DateTime.now());
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(Icons.chevron_left, () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                }),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF022C22),
                  ),
                ),
                _buildNavButton(Icons.chevron_right, () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                }),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays
                  .map((w) => SizedBox(
                        width: 40,
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final DateTime day = days[index];
                final isCurrentMonth = day.month == _focusedMonth.month;
                final isFuture = day.isAfter(today);
                final isStart = _isSameDay(day, _startDate);
                final isEnd = _isSameDay(day, _endDate);
                final isInRange = _startDate != null &&
                    _endDate != null &&
                    day.isAfter(_startDate!) &&
                    day.isBefore(_endDate!);
                final hasRange = _startDate != null && _endDate != null && !_isSameDay(_startDate, _endDate);

                BoxDecoration? rangeDecoration;
                if (isInRange) {
                  rangeDecoration = BoxDecoration(color: _softGreen);
                } else if (isStart && hasRange) {
                  rangeDecoration = BoxDecoration(
                    color: _softGreen,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  );
                } else if (isEnd && hasRange) {
                  rangeDecoration = BoxDecoration(
                    color: _softGreen,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                  );
                }

                return GestureDetector(
                  onTap: isFuture ? null : () => _onDayTap(day),
                  child: Container(
                    decoration: rangeDecoration,
                    alignment: Alignment.center,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: (isStart || isEnd)
                          ? BoxDecoration(color: _primaryGreen, shape: BoxShape.circle)
                          : null,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (isStart || isEnd || isInRange) ? FontWeight.bold : FontWeight.w500,
                          color: (isStart || isEnd)
                              ? Colors.white
                              : (isFuture || !isCurrentMonth)
                                  ? Colors.grey.shade300
                                  : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startDate == null
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            DateTimeRange(
                              start: _startDate!,
                              end: _endDate ?? _startDate!,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _primaryGreen,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}