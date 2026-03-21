import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../authentication/login_screen.dart';
import '../authentication/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _cityController;
  late AnimationController _textController;
  late Animation<double> _fadeAnim;
  late Animation<double> _cityRise;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _cityRise = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _cityController, curve: Curves.easeOutCubic),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _cityController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      _textController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cityController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFB2DFDB),
              Color(0xFF80CBC4),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Circular badge with tagline
                AnimatedBuilder(
                  animation: _cityRise,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _cityRise.value),
                      child: child,
                    );
                  },
                  child: _buildCircularBadge(size),
                ),

                const SizedBox(height: 32),

                // Tagline text
                FadeTransition(
                  opacity: _textFade,
                  child: _buildTagline(),
                ),

                const Spacer(),

                // Buttons
                FadeTransition(
                  opacity: _textFade,
                  child: _buildButtons(context),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularBadge(Size size) {
    return Container(
      width: size.width * 0.78,
      height: size.width * 0.78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating text around circle
          SizedBox(
            width: size.width * 0.78,
            height: size.width * 0.78,
            child: CustomPaint(
              painter: _CircularTextPainter(
                text: "CONSISTENCY IS CONSTRUCTION • CONSISTENCY IS CONSTRUCTION • ",
              ),
            ),
          ),

          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini city illustration
              _buildMiniCity(),
              const SizedBox(height: 12),
              Text(
                "Habit Builder",
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B5E20),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCity() {
    return SizedBox(
      height: 100,
      width: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Ground
          Positioned(
            bottom: 0,
            child: Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // Buildings
          _miniBuilding(left: 0, height: 60, width: 30, color: const Color(0xFF43A047), windows: 2),
          _miniBuilding(left: 35, height: 80, width: 38, color: const Color(0xFF1E88E5), windows: 3),
          _miniBuilding(left: 78, height: 95, width: 32, color: const Color(0xFF6D4C41), windows: 4),
          _miniBuilding(left: 115, height: 70, width: 36, color: const Color(0xFF00897B), windows: 3),
          _miniBuilding(left: 156, height: 50, width: 24, color: const Color(0xFF43A047), windows: 2),
          // Trees
          _miniTree(left: 22, size: 20),
          _miniTree(left: 148, size: 18),
        ],
      ),
    );
  }

  Widget _miniBuilding({
    required double left,
    required double height,
    required double width,
    required Color color,
    required int windows,
  }) {
    return Positioned(
      left: left,
      bottom: 10,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(
              windows,
                  (_) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _windowDot(),
                    _windowDot(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _windowDot() => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      color: Colors.yellow.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(1),
    ),
  );

  Widget _miniTree({required double left, required double size}) {
    return Positioned(
      left: left,
      bottom: 10,
      child: Icon(Icons.park, color: const Color(0xFF2E7D32), size: size),
    );
  }

  Widget _buildTagline() {
    return Column(
      children: [
        Text(
          "Your life is a city.",
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Build it one habit at a time.",
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF388E3C),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Get Started
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Get Started",
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Sign In
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  "Sign In",
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B5E20),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for circular text
class _CircularTextPainter extends CustomPainter {
  final String text;
  _CircularTextPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;

    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF2E7D32).withValues(alpha: 0.7),
      letterSpacing: 2.5,
    );

    final chars = text.characters.toList();
    final angleStep = (2 * 3.14159265) / chars.length;

    for (int i = 0; i < chars.length; i++) {
      final angle = i * angleStep - (3.14159265 / 2);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + 3.14159265 / 2);

      final tp = TextPainter(
        text: TextSpan(text: chars[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CircularTextPainter oldDelegate) => false;

  double cos(double angle) => _cos(angle);
  double sin(double angle) => _sin(angle);

  double _cos(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 8; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 8; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}