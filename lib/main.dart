import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_tab.dart'; 
import 'screens/data_tab.dart';
import 'screens/userprofile_tab.dart';
import 'screens/login_screen.dart'; 

Future<void> main() async {
  // Ensure Flutter bindings are initialized before calling async code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your unique keys
  await Supabase.initialize(
    url: 'https://reszkykrwtcvnvpcmdzj.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlc3preWtyd3Rjdm52cGNtZHpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3ODQ0NjgsImV4cCI6MjA5MDM2MDQ2OH0.Gm4S2tqhU1A0oLC6-5qs9MFlj5WzUFP2eHt2pL90DI0',                   
  );

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
  
  // ⭐ Changed to late variable
  late bool _isLoggedIn;

  // ⭐ ADDED: Dynamically check Supabase on load
  @override
  void initState() {
    super.initState();
    _isLoggedIn = Supabase.instance.client.auth.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(isLoggedIn: _isLoggedIn), 
      const Center(child: Text('AI Prediction Analysis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))), 
      const Center(child: Text('Manual Controls', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),       
      DataTab(isLoggedIn: _isLoggedIn),        
      SettingsTab(isLoggedIn: _isLoggedIn),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEDF7F0),
      appBar: AppBar(
        toolbarHeight: 70, 
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png', 
              width: 50, 
              height: 40,
              fit: BoxFit.contain,
            ), 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SensorHub AI', 
                  style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w900, fontSize: 18)
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: _isLoggedIn ? Colors.green : Colors.grey.shade400, size: 8),
                    const SizedBox(width: 4),
                    Text(
                      _isLoggedIn ? 'SYSTEM LIVE' : 'SYSTEM OFFLINE', 
                      style: TextStyle(
                        color: _isLoggedIn ? Colors.green : Colors.grey.shade500, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1.2
                      )
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFF064E3B)),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              // ⭐ UPDATED: Added async and Supabase sign out logic
              onSelected: (String value) async {
                if (value == 'logout') {
                  await Supabase.instance.client.auth.signOut();
                  setState(() {
                    _isLoggedIn = false;
                  });
                } else if (value == 'login') {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: true))
                  );
                } else if (value == 'signup') {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: false))
                  );
                } else if (value == 'switch_account') {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const LoginScreen(initialIsLogin: true))
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) {
                if (_isLoggedIn) {
                  return [
                    const PopupMenuItem(
                      value: 'switch_account',
                      child: Row(
                        children: [
                          Icon(Icons.switch_account, color: Color(0xFF064E3B), size: 18),
                          SizedBox(width: 12),
                          Text('Switch Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B))),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red, size: 18),
                          SizedBox(width: 12),
                          Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ];
                } else {
                  return [
                    const PopupMenuItem(
                      value: 'login',
                      child: Row(
                        children: [
                          Icon(Icons.login, color: Color(0xFF064E3B), size: 18),
                          SizedBox(width: 12),
                          Text('Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B))),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'signup',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: Color(0xFF064E3B), size: 18),
                          SizedBox(width: 12),
                          Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B))),
                        ],
                      ),
                    ),
                  ];
                }
              },
              child: CircleAvatar(
                backgroundColor: _isLoggedIn ? Colors.green : Colors.grey.shade400,
                radius: 16,
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
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
          backgroundColor: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.9),
          selectedItemColor: const Color.fromARGB(255, 73, 255, 82),
          unselectedItemColor: const Color.fromARGB(255, 253, 253, 253),
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