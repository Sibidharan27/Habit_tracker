import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/building_widget.dart';

// Each tile is 110x140 logical pixels
const double kTileW = 110;
const double kTileH = 148;
const int kCols = 3;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _applyDecay(
      String uid, List<QueryDocumentSnapshot> habits) async {
    final now = DateTime.now();
    for (final doc in habits) {
      final d = doc.data() as Map<String, dynamic>;
      final last = (d['lastCompleted'] as Timestamp).toDate();
      final missed = now.difference(last).inDays;
      if (missed > 1) {
        final newStreak = ((d['streak'] as int) - missed).clamp(0, 99999);
        await doc.reference
            .update({'streak': newStreak, 'level': newStreak ~/ 3});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final hour = DateTime.now().hour;

    final List<Color> skyColors;
    if (hour >= 5 && hour < 8) {
      skyColors = [const Color(0xFFFF8C69), const Color(0xFFFFD166), const Color(0xFF90CAF9)];
    } else if (hour >= 8 && hour < 18) {
      skyColors = [const Color(0xFF1565C0), const Color(0xFF42A5F5), const Color(0xFFB3E5FC)];
    } else if (hour >= 18 && hour < 21) {
      skyColors = [const Color(0xFF4A148C), const Color(0xFFFF7043), const Color(0xFFFFB74D)];
    } else {
      skyColors = [const Color(0xFF0D1B2A), const Color(0xFF1A237E), const Color(0xFF283593)];
    }

    return Scaffold(
      // FAB in top-right area — clean and always reachable
      floatingActionButton: _AddHabitFAB(uid: uid),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Stack(
        children: [
          // Sky
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: skyColors,
                ),
              ),
            ),
          ),

          // Clouds / Stars
          if (hour >= 6 && hour < 20) ...[
            Positioned(top: 100, left: -8, child: _Cloud(width: 100, opacity: 0.7)),
            Positioned(top: 76, right: 50, child: _Cloud(width: 75, opacity: 0.5)),
            Positioned(top: 148, left: 155, child: _Cloud(width: 60, opacity: 0.38)),
          ],
          if (hour >= 21 || hour < 5)
            Positioned.fill(child: CustomPaint(painter: _StarPainter())),

          // Main scrollable city content
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('habits')
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              final habits = snap.data!.docs;
              _applyDecay(uid, habits);

              return SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 80, 4),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting(hour),
                                  style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600)),
                              Text('My City',
                                  style: GoogleFonts.nunito(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ],
                          ),
                          const Spacer(),
                          // habit count badge
                          if (habits.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${habits.length} building${habits.length != 1 ? 's' : ''}',
                                style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── City grid ──
                    Expanded(
                      child: habits.isEmpty
                          ? _EmptyCity()
                          : _CityGrid(habits: habits),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _greeting(int h) {
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤';
    return 'Good evening 🌙';
  }
}

// ─────────────────────────────────────────────
// CITY GRID — tile-based, no overlap
// ─────────────────────────────────────────────
class _CityGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> habits;
  const _CityGrid({required this.habits});

  @override
  Widget build(BuildContext context) {
    // How many rows we need
    final rows = (habits.length / kCols).ceil();
    final screenW = MediaQuery.of(context).size.width;
    final tileW = screenW / kCols;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: SizedBox(
        width: screenW,
        height: rows * kTileH + 20,
        child: Stack(
          children: [
            // Ground patches under each tile
            ...List.generate(habits.length, (i) {
              final col = i % kCols;
              final row = i ~/ kCols;
              return Positioned(
                left: col * tileW,
                top: row * kTileH + kTileH - 22,
                width: tileW,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }),

            // Tile dividers (subtle)
            ...List.generate(habits.length, (i) {
              final col = i % kCols;
              final row = i ~/ kCols;
              return Positioned(
                left: col * tileW,
                top: row * kTileH,
                width: tileW,
                height: kTileH,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }),

            // Buildings
            ...habits.asMap().entries.map((entry) {
              final i = entry.key;
              final doc = entry.value;
              final d = doc.data() as Map<String, dynamic>;
              final col = i % kCols;
              final row = i ~/ kCols;
              return Positioned(
                left: col * tileW,
                top: row * kTileH,
                width: tileW,
                height: kTileH,
                child: BuildingWidget(
                  habitName: d['habitName'] ?? d['category'],
                  category: d['category'],
                  docId: doc.id,
                  level: d['level'],
                  tileWidth: tileW,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAB — top right, pill shaped
// ─────────────────────────────────────────────
class _AddHabitFAB extends StatelessWidget {
  final String uid;
  const _AddHabitFAB({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 52),
      child: GestureDetector(
        onTap: () => _showAddHabitSheet(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text('Add Habit',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyCity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏗️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 14),
          Text('Your city is empty!',
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('Tap Add Habit to build your first building',
              style:
              GoogleFonts.nunito(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLOUD
// ─────────────────────────────────────────────
class _Cloud extends StatelessWidget {
  final double width;
  final double opacity;
  const _Cloud({required this.width, required this.opacity});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: width,
      height: width * 0.42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// STAR PAINTER
// ─────────────────────────────────────────────
class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.8);
    const dots = [
      [0.1, 0.05], [0.25, 0.12], [0.45, 0.03], [0.7, 0.08],
      [0.85, 0.04], [0.15, 0.18], [0.6, 0.15], [0.9, 0.2],
      [0.35, 0.22], [0.78, 0.25],
    ];
    for (final d in dots) {
      canvas.drawCircle(Offset(size.width * d[0], size.height * d[1]), 1.5, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}

// ─────────────────────────────────────────────
// ADD HABIT SHEET
// ─────────────────────────────────────────────
void _showAddHabitSheet(BuildContext context) {
  final nameCtrl = TextEditingController();
  String selectedCat = 'workout';

  const cats = [
    {'value': 'workout',          'label': 'Workout',     'emoji': '🏋️', 'color': 0xFFE53935},
    {'value': 'study',            'label': 'Study',       'emoji': '📚', 'color': 0xFF1E88E5},
    {'value': 'work',             'label': 'Work',        'emoji': '🏢', 'color': 0xFF546E7A},
    {'value': 'self_improvement', 'label': 'Self Growth', 'emoji': '🌱', 'color': 0xFF43A047},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('🏗️', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Habit',
                      style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1B5E20))),
                  Text('Build something in your city',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: Colors.grey.shade500)),
                ]),
              ]),
              const SizedBox(height: 22),
              Text('HABIT NAME',
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF388E3C),
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20)),
                decoration: InputDecoration(
                  hintText: 'e.g. Morning Run, Read 30 mins…',
                  hintStyle:
                  GoogleFonts.nunito(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.edit_note_rounded,
                      color: Color(0xFF43A047)),
                  filled: true,
                  fillColor: const Color(0xFFF1F8E9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF43A047), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
                ),
              ),
              const SizedBox(height: 20),
              Text('BUILDING TYPE',
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF388E3C),
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: cats.map((cat) {
                  final sel = selectedCat == cat['value'];
                  final clr = Color(cat['color'] as int);
                  return GestureDetector(
                    onTap: () =>
                        setS(() => selectedCat = cat['value'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: sel
                            ? clr.withValues(alpha: 0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel ? clr : Colors.grey.shade200,
                            width: sel ? 2 : 1),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Text(cat['emoji'] as String,
                            style: const TextStyle(fontSize: 19)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(cat['label'] as String,
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: sel
                                      ? clr
                                      : Colors.grey.shade600)),
                        ),
                        if (sel)
                          Icon(Icons.check_circle_rounded,
                              color: clr, size: 16),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Please enter a habit name!',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                    return;
                  }
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('habits')
                      .add({
                    'habitName': name,
                    'category': selectedCat,
                    'streak': 0,
                    'level': 0,
                    'posX': 0.0,
                    'posY': 0.0,
                    'lastCompleted': DateTime.now(),
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Text('🏗️'),
                      const SizedBox(width: 8),
                      Text('$name added to your city!',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700)),
                    ]),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text('Build This Habit',
                          style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}