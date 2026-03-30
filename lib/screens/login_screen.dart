import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; 

class LoginScreen extends StatefulWidget {
  // ⭐ Added variable to control initial view
  final bool initialIsLogin; 
  
  const LoginScreen({super.key, this.initialIsLogin = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ⭐ Changed to 'late' so we can set it in initState
  late bool _isLogin; 
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; 
  bool _isLoading = false; 

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _bgLight = const Color(0xFFE8F5E9);
  final Color _darkButton = const Color(0xFF064E3B);
  final Color _textDark = const Color(0xFF022C22);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // ⭐ Set the initial state based on what button was clicked
    _isLogin = widget.initialIsLogin; 
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true; 
    });

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final confirmPassword = _confirmPasswordController.text.trim();
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        await supabase.auth.signUp(
          email: email,
          password: password,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      debugPrint('🚨 REAL ERROR: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, 
          thickness: 6,
          radius: const Radius.circular(10),
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420), 
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.green.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: Icon(Icons.arrow_back, color: _textDark),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context, 
                                    MaterialPageRoute(builder: (context) => const DashboardScreen())
                                  );
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -4), 
                                  child: Transform.scale(
                                    scale: 1.5, 
                                    child: Image.asset(
                                      'assets/logo.png', 
                                      width: 30,  
                                      height: 25, 
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'SensorHub AI',
                                  style: TextStyle(color: _textDark, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: const DecorationImage(
                              image: NetworkImage('https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?q=80&w=800&auto=format&fit=crop'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [_darkButton.withOpacity(0.6), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
                        child: Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          style: TextStyle(color: _textDark, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        'Manage your ecosystem from anywhere',
                        style: TextStyle(color: Colors.green.shade800.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: _buildToggleBtn('Login', true)),
                              Expanded(child: _buildToggleBtn('Sign Up', false)),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildTextField(
                              label: 'Email Address',
                              hint: 'name@example.com',
                              icon: Icons.mail_outline,
                              controller: _emailController, 
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              controller: _passwordController, 
                            ),
                            
                            if (!_isLogin) ...[
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'Confirm Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                isConfirmPassword: true,
                                controller: _confirmPasswordController, 
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _authenticate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _darkButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: _darkButton.withOpacity(0.4),
                                ),
                                child: _isLoading 
                                  ? const SizedBox(
                                      height: 24, 
                                      width: 24, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                    )
                                  : Text(
                                      _isLogin ? 'Sign In' : 'Create Account',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Colors.green.shade100)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(color: Colors.green.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.green.shade100)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildSocialButton('Google', Icons.g_mobiledata, Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Container(height: 8, width: double.infinity, color: _primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isLoginBtn) {
    bool isSelected = _isLogin == isLoginBtn;
    return GestureDetector(
      onTap: () => setState(() => _isLogin = isLoginBtn),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.green.shade800.withOpacity(0.6),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required IconData icon, bool isPassword = false, bool isConfirmPassword = false, required TextEditingController controller}) {
    bool currentObscure = isConfirmPassword ? _obscureConfirmPassword : _obscurePassword;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.bold)),
            if (isPassword && !isConfirmPassword && _isLogin)
              Text('Forgot?', style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller, 
          obscureText: isPassword && currentObscure,
          style: TextStyle(color: Colors.green.shade900, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.green.shade300),
            prefixIcon: Icon(icon, color: Colors.green.shade400),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(currentObscure ? Icons.visibility_off : Icons.visibility, color: Colors.green.shade400),
                    onPressed: () {
                      setState(() {
                        if (isConfirmPassword) {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        } else {
                          _obscurePassword = !_obscurePassword;
                        }
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.green.shade50.withOpacity(0.5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(String text, IconData icon, Color iconColor) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: iconColor, size: 28), 
      label: Text(text, style: const TextStyle(color: Color(0xFF022C22), fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.green.shade100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
      ),
    );
  }
}