import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/building_widget.dart';

// ── Grid constants ──
const int kGridCols = 5;
const int kGridRows = 12;
const double kTileSize = 80.0; // each cell is 80×80 logical px

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _applyDecay(String uid, List<QueryDocumentSnapshot> habits) async {
    final now = DateTime.now();
    for (final doc in habits) {
      final d = doc.data() as Map<String, dynamic>;
      final last = (d['lastCompleted'] as dynamic).toDate() as DateTime;
      final intervalHours = (d['intervalHours'] as num?)?.toInt() ?? 24;
      final missedHours = now.difference(last).inHours;
      // Decay if missed more than 2x the interval
      if (missedHours > intervalHours * 2) {
        final missedCycles = missedHours ~/ intervalHours;
        final newStreak = ((d['streak'] as int) - missedCycles).clamp(0, 99999);
        final newLevel = (newStreak ~/ 3).clamp(1, 5);
        await doc.reference.update({'streak': newStreak, 'level': newLevel});
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
      floatingActionButton: _AddHabitFAB(uid: uid),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Stack(
        children: [
          // Sky gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: skyColors,
                ),
              ),
            ),
          ),

          // Clouds / Stars
          if (hour >= 6 && hour < 20) ...[
            _AnimatedCloud(width: 110, opacity: 0.6, startX: -30, topY: 80, duration: const Duration(seconds: 45)),
            _AnimatedCloud(width: 80, opacity: 0.45, startX: 120, topY: 110, duration: const Duration(seconds: 60)),
            _AnimatedCloud(width: 65, opacity: 0.35, startX: 220, topY: 55, duration: const Duration(seconds: 35)),
          ],
          if (hour >= 21 || hour < 5)
            Positioned.fill(child: CustomPaint(painter: _StarPainter())),

          // City content
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users').doc(uid).collection('habits').snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final habits = snap.data!.docs;
              _applyDecay(uid, habits);

              return SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 80, 4),
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_greeting(hour), style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                          Text('My City', style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                        ]),
                        const Spacer(),
                        if (habits.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                            child: Text('${habits.length} 🏠', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    ),

                    // ── City Grid ──
                    Expanded(
                      child: habits.isEmpty
                          ? _EmptyCity()
                          : _CoCCityGrid(habits: habits, uid: uid),
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
// COC-STYLE CITY GRID
// ─────────────────────────────────────────────
class _CoCCityGrid extends StatefulWidget {
  final List<QueryDocumentSnapshot> habits;
  final String uid;
  const _CoCCityGrid({required this.habits, required this.uid});

  @override
  State<_CoCCityGrid> createState() => _CoCCityGridState();
}

class _CoCCityGridState extends State<_CoCCityGrid> {
  String? _draggingDocId;
  int? _hoverCol;
  int? _hoverRow;

  /// Build a map of "col,row" → docId for occupied cells.
  Map<String, String> _buildOccupancy() {
    final map = <String, String>{};
    for (final doc in widget.habits) {
      final d = doc.data() as Map<String, dynamic>;
      final gx = (d['gridX'] as num?)?.toInt() ?? 0;
      final gy = (d['gridY'] as num?)?.toInt() ?? 0;
      map['$gx,$gy'] = doc.id;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final occupancy = _buildOccupancy();

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(60),
      minScale: 0.5,
      maxScale: 2.5,
      constrained: false,
      child: SizedBox(
        width:  kGridCols * kTileSize,
        height: kGridRows * kTileSize,
        child: Stack(
          children: [
            // ── Island terrain ──
            Positioned.fill(child: CustomPaint(painter: _IslandTerrainPainter())),

            // ── Grid cells (DragTargets) — only visible during drag ──
            ...List.generate(kGridRows * kGridCols, (i) {
              final col = i % kGridCols;
              final row = i ~/ kGridCols;
              final key = '$col,$row';
              final occupiedByOther = occupancy.containsKey(key) && occupancy[key] != _draggingDocId;
              final isHover = col == _hoverCol && row == _hoverRow;
              final isDragging = _draggingDocId != null;

              return Positioned(
                left: col * kTileSize,
                top:  row * kTileSize,
                width:  kTileSize,
                height: kTileSize,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    setState(() { _hoverCol = col; _hoverRow = row; });
                    return !occupiedByOther;
                  },
                  onLeave: (_) => setState(() { _hoverCol = null; _hoverRow = null; }),
                  onAcceptWithDetails: (details) {
                    setState(() { _hoverCol = null; _hoverRow = null; });
                    if (!occupiedByOther) {
                      FirebaseFirestore.instance
                          .collection('users').doc(widget.uid)
                          .collection('habits').doc(details.data)
                          .update({'gridX': col, 'gridY': row});
                    }
                  },
                  builder: (ctx, candidates, rejects) => Container(
                    decoration: BoxDecoration(
                      border: isDragging
                          ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.5)
                          : null,
                      color: isHover
                          ? (occupiedByOther
                              ? Colors.red.withValues(alpha: 0.4)
                              : Colors.green.withValues(alpha: 0.4))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),

            // ── Buildings ──
            ...widget.habits.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final col = (d['gridX'] as num?)?.toInt() ?? 0;
              final row = (d['gridY'] as num?)?.toInt() ?? 0;
              final level    = (d['level'] as num?)?.toInt() ?? 1;
              final intervalHours = (d['intervalHours'] as num?)?.toInt() ?? 24;
              final habitName = (d['habitName'] as String?) ?? (d['category'] as String? ?? '');

              final buildingWidget = BuildingWidget(
                habitName: habitName,
                category: d['category'] ?? 'self_improvement',
                docId: doc.id,
                level: level,
                intervalHours: intervalHours,
                tileSize: kTileSize,
              );

              return Positioned(
                left: col * kTileSize,
                top:  row * kTileSize,
                width:  kTileSize,
                height: kTileSize,
                child: LongPressDraggable<String>(
                  data: doc.id,
                  delay: const Duration(milliseconds: 300),
                  onDragStarted: () => setState(() => _draggingDocId = doc.id),
                  onDragEnd: (_)        => setState(() => _draggingDocId = null),
                  onDraggableCanceled: (_, __) => setState(() => _draggingDocId = null),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.85,
                      child: SizedBox(
                        width: kTileSize, height: kTileSize,
                        child: buildingWidget,
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.25, child: buildingWidget),
                  child: buildingWidget,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Rich Island Terrain Painter ──
class _IslandTerrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    // Base grass
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF4CAF50));
    // Grass variation patches
    final shades = [const Color(0xFF43A047), const Color(0xFF388E3C), const Color(0xFF66BB6A), const Color(0xFF2E7D32)];
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 20.0 + rng.nextDouble() * 50;
      final h = 15.0 + rng.nextDouble() * 40;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h),
          Paint()..color = shades[rng.nextInt(shades.length)].withValues(alpha: 0.4));
    }
    // Dirt patches
    for (int i = 0; i < 12; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 18 + rng.nextDouble() * 25, height: 10 + rng.nextDouble() * 15),
          Paint()..color = const Color(0xFF8D6E63).withValues(alpha: 0.25));
    }
    // Flower dots
    final flowerColors = [const Color(0xFFFFEB3B), const Color(0xFFFF8A65), const Color(0xFFE1BEE7), const Color(0xFFFFFFFF)];
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 1.5,
          Paint()..color = flowerColors[rng.nextInt(flowerColors.length)].withValues(alpha: 0.6));
    }
    // Small bush clusters at edges
    for (int i = 0; i < 8; i++) {
      final edge = rng.nextInt(4);
      double bx, by;
      if (edge == 0) { bx = rng.nextDouble() * size.width; by = rng.nextDouble() * 20; }
      else if (edge == 1) { bx = rng.nextDouble() * size.width; by = size.height - rng.nextDouble() * 20; }
      else if (edge == 2) { bx = rng.nextDouble() * 20; by = rng.nextDouble() * size.height; }
      else { bx = size.width - rng.nextDouble() * 20; by = rng.nextDouble() * size.height; }
      canvas.drawCircle(Offset(bx, by), 6 + rng.nextDouble() * 5,
          Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.6));
      canvas.drawCircle(Offset(bx + 4, by - 3), 4 + rng.nextDouble() * 3,
          Paint()..color = const Color(0xFF1B5E20).withValues(alpha: 0.5));
    }
    // Stone path segments
    final pathPaint = Paint()..color = const Color(0xFF9E9E9E).withValues(alpha: 0.3);
    for (int i = 0; i < 6; i++) {
      final px = rng.nextDouble() * size.width;
      final py = rng.nextDouble() * size.height;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(px, py), width: 12, height: 6), const Radius.circular(3)), pathPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// FAB
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
            gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text('Add Habit', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏗️', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 14),
        Text('Your city is empty!', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 6),
        Text('Tap Add Habit to build your first building', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white70)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// CLOUD
// ─────────────────────────────────────────────
class _AnimatedCloud extends StatefulWidget {
  final double width;
  final double opacity;
  final double startX;
  final double topY;
  final Duration duration;
  const _AnimatedCloud({required this.width, required this.opacity, required this.startX, required this.topY, required this.duration});
  @override
  State<_AnimatedCloud> createState() => _AnimatedCloudState();
}
class _AnimatedCloudState extends State<_AnimatedCloud> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Positioned(
      left: 0, right: 0, top: widget.topY, height: widget.width * 0.4,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final dx = (widget.startX + _ctrl.value * (screenW + widget.width)) % (screenW + widget.width) - widget.width;
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(opacity: widget.opacity, child: Container(
                width: widget.width, height: widget.width * 0.4,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
              )),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STARS
// ─────────────────────────────────────────────
class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.8);
    const dots = [[0.1, 0.05], [0.25, 0.12], [0.45, 0.03], [0.7, 0.08], [0.85, 0.04], [0.15, 0.18], [0.6, 0.15], [0.9, 0.2], [0.35, 0.22], [0.78, 0.25]];
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
  int selectedInterval = 24;

  const cats = [
    {'value': 'workout',          'label': 'Workout',     'emoji': '🏋️', 'color': 0xFFE53935},
    {'value': 'study',            'label': 'Study',       'emoji': '📚', 'color': 0xFF1E88E5},
    {'value': 'work',             'label': 'Work',        'emoji': '🏢', 'color': 0xFF546E7A},
    {'value': 'self_improvement', 'label': 'Self Growth', 'emoji': '🌱', 'color': 0xFF43A047},
  ];

  final intervalOptions = [
    {'hours': 1,  'label': '1 Hour',  'emoji': '⚡'},
    {'hours': 2,  'label': '2 Hours', 'emoji': '💧'},
    {'hours': 4,  'label': '4 Hours', 'emoji': '🔥'},
    {'hours': 12, 'label': '12 Hours','emoji': '🌗'},
    {'hours': 24, 'label': 'Daily',   'emoji': '📅'},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14)),
                  child: const Text('🏗️', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Habit', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                  Text('Build something in your city', style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade500)),
                ]),
              ]),
              const SizedBox(height: 22),
              _sheetLabel('HABIT NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
                decoration: InputDecoration(
                  hintText: 'e.g. Morning Run, Drink Water…',
                  hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF43A047)),
                  filled: true, fillColor: const Color(0xFFF1F8E9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF43A047), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
              const SizedBox(height: 20),
              _sheetLabel('BUILDING TYPE'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: cats.map((cat) {
                  final sel = selectedCat == cat['value'];
                  final clr = Color(cat['color'] as int);
                  return GestureDetector(
                    onTap: () => setS(() => selectedCat = cat['value'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: sel ? clr.withValues(alpha: 0.1) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? clr : Colors.grey.shade200, width: sel ? 2 : 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Text(cat['emoji'] as String, style: const TextStyle(fontSize: 19)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cat['label'] as String, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: sel ? clr : Colors.grey.shade600))),
                        if (sel) Icon(Icons.check_circle_rounded, color: clr, size: 16),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _sheetLabel('REMINDER INTERVAL'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: intervalOptions.map((opt) {
                  final hours = opt['hours'] as int;
                  final sel = selectedInterval == hours;
                  return GestureDetector(
                    onTap: () => setS(() => selectedInterval = hours),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? const Color(0xFF43A047) : Colors.grey.shade200, width: sel ? 2 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(opt['emoji'] as String, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(opt['label'] as String, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? const Color(0xFF1B5E20) : Colors.grey.shade600)),
                        if (sel) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 14),
                        ],
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
                      content: Text('Please enter a habit name!', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                    return;
                  }
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  // Find next empty grid cell
                  final existing = await FirebaseFirestore.instance
                      .collection('users').doc(uid).collection('habits').get();
                  final occupied = <String>{};
                  for (final h in existing.docs) {
                    final hd = h.data();
                    final gx = (hd['gridX'] as num?)?.toInt() ?? 0;
                    final gy = (hd['gridY'] as num?)?.toInt() ?? 0;
                    occupied.add('$gx,$gy');
                  }
                  int newX = 0, newY = 0;
                  outer:
                  for (int row = 0; row < kGridRows; row++) {
                    for (int col = 0; col < kGridCols; col++) {
                      if (!occupied.contains('$col,$row')) { newX = col; newY = row; break outer; }
                    }
                  }

                  await FirebaseFirestore.instance
                      .collection('users').doc(uid).collection('habits')
                      .add({
                    'habitName': name,
                    'category':  selectedCat,
                    'streak':    0,
                    'level':     1,
                    'gridX':     newX,
                    'gridY':     newY,
                    'intervalHours': selectedInterval,
                    'lastCompleted': DateTime.now(),
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Text('🏗️'),
                      const SizedBox(width: 8),
                      Text('$name added to your city!', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                    ]),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text('Build This Habit', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
                  ]),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    ),
  );
}

Text _sheetLabel(String t) => Text(t, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF388E3C), letterSpacing: 1.5));