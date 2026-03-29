import 'package:flutter/material.dart';
import 'screens/home_tab.dart'; 
import 'screens/data_tab.dart';
import 'screens/userprofile_tab.dart';

void main() {
  runApp(const SmartGreenhouseApp());
}

class SmartGreenhouseApp extends StatelessWidget {
  const SmartGreenhouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SensorHub AI',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEDF7F0),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        fontFamily: 'Manrope', 
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; 

  @override
  Widget build(BuildContext context) {
    
    // The list of screens your bottom navigation bar switches between
    final List<Widget> pages = [
      const HomeTab(), 
      const Center(child: Text('AI Prediction Analysis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))), 
      const Center(child: Text('Manual Controls', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),       
      const DataTab(),        
      const SettingsTab(), // Updated to match the class name in userprofile_tab.dart
    ]; // This closing bracket was missing in your code

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SensorHub AI', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w900, fontSize: 18)),
            Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 4),
                Text('SYSTEM LIVE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view, color: Color(0xFF064E3B)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFF064E3B)),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.green,
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
      
      body: pages[_selectedIndex], 

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed, 
          backgroundColor: Colors.white.withOpacity(0.9),
          selectedItemColor: Colors.green.shade800,
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          onTap: (int index) {
            setState(() {
              _selectedIndex = index; 
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI'),
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'CONTROLS'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'DATA'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'SETTINGS'),
          ],
        ),
      ),
    );
  }
}