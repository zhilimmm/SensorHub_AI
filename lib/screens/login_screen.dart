import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; 

class LoginScreen extends StatefulWidget {
  final bool initialIsLogin; 
  
  const LoginScreen({super.key, this.initialIsLogin = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isLogin; 
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true; 
  bool _isLoading = false; 

  // Password Validation States
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ⭐ NEW: Added a FocusNode to track when the user clicks the password field
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordFocused = false;

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _bgLight = const Color(0xFFE8F5E9);
  final Color _darkButton = const Color(0xFF064E3B);
  final Color _textDark = const Color(0xFF022C22);
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin; 

    // ⭐ NEW: Listen for focus changes (clicks) on the password box
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification successful! Welcome.'), backgroundColor: Colors.green),
          );
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (Route<dynamic> route) => false
          );
        }
      }
    });
  }

  void _checkPasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[^a-zA-Z0-9]')); 
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel(); 
    _passwordFocusNode.dispose(); // ⭐ Always dispose FocusNodes!
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

    if (!_isLogin) {
      if (!_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please meet all password requirements.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isLoading = true); 

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
        }
      } else {
        final confirmPassword = _confirmPasswordController.text.trim();
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        final AuthResponse res = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (mounted) {
          if (res.session == null) {
            _showVerificationDialog(email, password);
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); 
      }
    }
  }

  void _showVerificationDialog(String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined, 
                    color: Color(0xFF064E3B), 
                    size: 44
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Check your inbox',
                  style: TextStyle(
                    color: Color(0xFF022C22),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Color(0xFF064E3B), fontSize: 15, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check your inbox and spam folder. Once clicked, return here.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF064E3B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      try {
                        final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
                        if (res.session != null && mounted) {
                          Navigator.pop(context); 
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account verified successfully!'), backgroundColor: Colors.green),
                          );
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not verified yet. Please check your email.'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text("I've verified my email", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                      setState(() {
                        _isLogin = true; 
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
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
                              focusNode: _passwordFocusNode, // ⭐ Hooked up FocusNode
                              onChanged: (val) => _checkPasswordRequirements(),
                            ),
                            
                            // ⭐ NEW: Wrapped in AnimatedSize. It expands beautifully when focused!
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: (!_isLogin && (_isPasswordFocused || _passwordController.text.isNotEmpty))
                                ? _buildPasswordRequirements() 
                                : const SizedBox.shrink(),
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

  Widget _buildPasswordRequirements() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequirementRow('One uppercase letter', _hasUppercase),
          _buildRequirementRow('One lowercase letter', _hasLowercase),
          _buildRequirementRow('One number', _hasNumber),
          _buildRequirementRow('One special character (e.g. @, #, \$, &, *)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isMet ? Colors.green.shade700 : Colors.red.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMet ? Colors.green.shade700 : Colors.red.shade400,
            ),
          ),
        ],
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

  // ⭐ NEW: Added the FocusNode parameter to the method signature
  Widget _buildTextField({required String label, required String hint, required IconData icon, bool isPassword = false, bool isConfirmPassword = false, required TextEditingController controller, Function(String)? onChanged, FocusNode? focusNode}) {
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
          focusNode: focusNode, // ⭐ Hooked up the FocusNode here!
          obscureText: isPassword && currentObscure,
          onChanged: onChanged, 
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