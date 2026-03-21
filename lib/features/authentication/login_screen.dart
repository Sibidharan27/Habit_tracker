import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isSendingReset = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Failed: $e"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _handleForgotPassword() async {
    String email = emailController.text.trim();

    // If email field empty, ask via dialog
    if (email.isEmpty) {
      final emailDialogController = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 12),
                Text(
                  "Reset Password",
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enter your registered email address.",
                  style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailDialogController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "your@email.com",
                    filled: true,
                    fillColor: const Color(0xFFF1F8E9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF43A047)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: Text("Cancel",
                    style: GoogleFonts.nunito(
                        color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, emailDialogController.text.trim()),
                child: Text("Send Link",
                    style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
      emailDialogController.dispose();
      if (entered == null || entered.isEmpty) return;
      email = entered;
    }

    if (!email.contains('@') || !email.contains('.')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please enter a valid email address.",
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    // Show loading
    setState(() => isSendingReset = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.mark_email_read_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Reset link sent to $email\nCheck your inbox (and spam folder).",
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isSendingReset = false);
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = "No account found with that email.";
          break;
        case 'invalid-email':
          msg = "Invalid email address format.";
          break;
        case 'too-many-requests':
          msg = "Too many attempts. Try again later.";
          break;
        default:
          msg = "Error: ${e.message ?? e.code}";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Unexpected error: $e",
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Opacity(
                    opacity: _animController.value,
                    child: child,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Header with city skyline
                      _buildHeader(),

                      const SizedBox(height: 36),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back 👋",
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Your city is waiting for you.",
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Email field
                            _buildLabel("Email"),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: emailController,
                              hint: "you@example.com",
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty ? "Enter your email" : null,
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            _buildLabel("Password"),
                            const SizedBox(height: 6),
                            _buildPasswordField(),

                            const SizedBox(height: 8),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: isSendingReset ? null : _handleForgotPassword,
                                child: isSendingReset
                                    ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2E7D32),
                                  ),
                                )
                                    : Text(
                                  "Forgot password? Reset",
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Sign in button
                            _buildSignInButton(),

                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    "or",
                                    style: GoogleFonts.nunito(
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Create account
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8E9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF81C784),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Create an Account 🏗️",
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini skyline
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _skylineBuilding(height: 36, width: 22, color: const Color(0xFF43A047)),
            const SizedBox(width: 4),
            _skylineBuilding(height: 52, width: 28, color: const Color(0xFF1E88E5)),
            const SizedBox(width: 4),
            _skylineBuilding(height: 64, width: 24, color: const Color(0xFF6D4C41)),
            const SizedBox(width: 4),
            _skylineBuilding(height: 48, width: 28, color: const Color(0xFF00897B)),
            const SizedBox(width: 4),
            _skylineBuilding(height: 38, width: 22, color: const Color(0xFF43A047)),
          ],
        ),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            "Habit Builder",
            style: GoogleFonts.nunito(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1B5E20),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Center(
          child: Text(
            "SIGN IN",
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF66BB6A),
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skylineBuilding({required double height, required double width, required Color color}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF388E3C),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1B5E20),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFF43A047), size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F8E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: _obscurePassword,
      validator: (v) => v!.length < 6 ? "Minimum 6 characters" : null,
      style: GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1B5E20),
      ),
      decoration: InputDecoration(
        hintText: "••••••••",
        hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF43A047), size: 20),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF1F8E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: isLoading ? null : loginUser,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade400, Colors.grey.shade300]
                : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Sign In",
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}