import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

const int kMaxLevel = 5;

class BuildingWidget extends StatefulWidget {
  final String habitName;
  final String category;
  final String docId;
  final int level;
  final int intervalHours;
  final double tileSize;

  const BuildingWidget({
    super.key,
    required this.habitName,
    required this.category,
    required this.docId,
    required this.level,
    required this.intervalHours,
    required this.tileSize,
  });

  @override
  State<BuildingWidget> createState() => _BuildingWidgetState();
}

class _BuildingWidgetState extends State<BuildingWidget>
    with SingleTickerProviderStateMixin {
  bool isGlowing = false;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  String _assetPath() {
    final lvl = widget.level.clamp(1, kMaxLevel);
    return 'assets/buildings/${widget.category}/lvl$lvl.png';
  }

  Color get _color {
    switch (widget.category) {
      case 'workout': return const Color(0xFFE53935);
      case 'study':   return const Color(0xFF1E88E5);
      case 'work':    return const Color(0xFF546E7A);
      default:        return const Color(0xFF43A047);
    }
  }

  String get _emoji {
    switch (widget.category) {
      case 'workout': return '🏋️';
      case 'study':   return '📚';
      case 'work':    return '🏢';
      default:        return '🌱';
    }
  }

  bool get _isMax => widget.level >= kMaxLevel;

  String _formatDuration(int hours) {
    if (hours >= 24) return '${hours ~/ 24}d ${hours % 24}h';
    if (hours >= 1) return '${hours}h';
    return 'less than 1h';
  }

  // ── Complete habit ──
  Future<void> _complete(BuildContext ctx) async {
    if (await Vibration.hasVibrator()) Vibration.vibrate(duration: 60);
    _bounceCtrl.forward(from: 0);
    setState(() => isGlowing = true);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => isGlowing = false);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('habits').doc(widget.docId);
    final doc = await ref.get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    final last = (d['lastCompleted'] as dynamic).toDate() as DateTime;
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(ctx);

    // Check if enough time has passed since last completion
    final hoursSinceLast = now.difference(last).inHours;
    final intervalHours = (d['intervalHours'] as num?)?.toInt() ?? 24;
    if (hoursSinceLast < intervalHours) {
      final remaining = intervalHours - hoursSinceLast;
      messenger.showSnackBar(_snack('⏳  Come back in ${_formatDuration(remaining)}!', const Color(0xFF388E3C)));
      return;
    }

    final oldStreak = (d['streak'] as int);
    final newStreak = oldStreak + 1;
    final oldLevel  = (d['level'] as int);
    final newLevel  = (newStreak ~/ 3).clamp(1, kMaxLevel);

    await ref.update({'streak': newStreak, 'level': newLevel, 'lastCompleted': now});
    if (!mounted) return;

    if (newLevel > oldLevel) {
      final badge = newLevel >= kMaxLevel ? 'MAX 🌟' : 'Lvl $newLevel';
      messenger.showSnackBar(_snack(
          '🎉  ${widget.habitName} leveled up! → $badge', Colors.orange.shade700, duration: 3));
    } else {
      messenger.showSnackBar(
          _snack('🔥  ${widget.habitName}  •  Streak: $newStreak', const Color(0xFF2E7D32)));
    }

    // Auto-spawn: if already at max AND still hitting max, create adjacent building
    if (oldLevel >= kMaxLevel && newLevel >= kMaxLevel) {
      await _spawnAdjacentBuilding(uid, d);
    }
  }

  Future<void> _spawnAdjacentBuilding(String uid, Map<String, dynamic> d) async {
    final habitsCol = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('habits');

    // Build occupancy map
    final existing = await habitsCol.get();
    final occupied = <String>{};
    for (final h in existing.docs) {
      final hd = h.data();
      final gx = (hd['gridX'] as num?)?.toInt() ?? 0;
      final gy = (hd['gridY'] as num?)?.toInt() ?? 0;
      occupied.add('$gx,$gy');
    }

    final myX = (d['gridX'] as num?)?.toInt() ?? 0;
    final myY = (d['gridY'] as num?)?.toInt() ?? 0;

    // Try adjacent cells: right, left, down, up
    final candidates = [
      [myX + 1, myY], [myX - 1, myY],
      [myX, myY + 1], [myX, myY - 1],
    ];

    int? newX, newY;
    for (final c in candidates) {
      final cx = c[0]; final cy = c[1];
      if (cx >= 0 && cx < 5 && cy >= 0 && cy < 12 && !occupied.contains('$cx,$cy')) {
        newX = cx; newY = cy; break;
      }
    }

    // BFS fallback if no adjacent empty cell
    if (newX == null) {
      for (int row = 0; row < 12 && newX == null; row++) {
        for (int col = 0; col < 5 && newX == null; col++) {
          if (!occupied.contains('$col,$row')) { newX = col; newY = row; }
        }
      }
    }
    if (newX == null) return; // grid full

    // Determine generation suffix (II, III, IV…)
    final baseName = (d['habitName'] as String?) ?? widget.habitName;
    final count = existing.docs.where((h) {
      final hn = (h.data()['habitName'] as String?) ?? '';
      return hn == baseName || hn.startsWith('$baseName ');
    }).length;
    final suffixes = ['II', 'III', 'IV', 'V', 'VI', 'VII'];
    final newName = count <= suffixes.length
        ? '$baseName ${suffixes[count - 1]}'
        : '$baseName $count';

    await habitsCol.add({
      'habitName': newName,
      'category':  d['category'],
      'streak':    0,
      'level':     1,
      'gridX':     newX,
      'gridY':     newY,
      'intervalHours':  (d['intervalHours'] as num?)?.toInt() ?? 24,
      'lastCompleted': DateTime.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
          '🏙️  ${widget.habitName} district is expanding!', Colors.purple.shade600, duration: 3));
    }
  }

  // ── Edit dialog ──
  void _edit(BuildContext ctx) {
    final ctrl = TextEditingController(text: widget.habitName);
    String selectedCat = widget.category;
    int selectedInterval = widget.intervalHours;

    const cats = [
      {'value': 'workout',          'label': 'Workout',     'emoji': '🏋️', 'color': 0xFFE53935},
      {'value': 'study',            'label': 'Study',       'emoji': '📚', 'color': 0xFF1E88E5},
      {'value': 'work',             'label': 'Work',        'emoji': '🏢', 'color': 0xFF546E7A},
      {'value': 'self_improvement', 'label': 'Self Growth', 'emoji': '🌱', 'color': 0xFF43A047},
    ];

    final intervalOptions = [
      {'hours': 1,  'label': '1 Hour',   'sub': 'Complete every hour'},
      {'hours': 2,  'label': '2 Hours',  'sub': 'Complete every 2 hours'},
      {'hours': 4,  'label': '4 Hours',  'sub': 'Complete every 4 hours'},
      {'hours': 12, 'label': '12 Hours', 'sub': 'Complete twice a day'},
      {'hours': 24, 'label': 'Daily',    'sub': 'Complete once a day'},
    ];

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF2E7D32), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Edit Habit', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1B5E20))),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _label('HABIT NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
                  decoration: InputDecoration(
                    filled: true, fillColor: const Color(0xFFF1F8E9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF43A047), width: 2)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  ),
                ),
                const SizedBox(height: 16),
                _label('BUILDING TYPE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: cats.map((cat) {
                    final sel = selectedCat == cat['value'];
                    final clr = Color(cat['color'] as int);
                    return GestureDetector(
                      onTap: () => setD(() => selectedCat = cat['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? clr.withValues(alpha: 0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? clr : Colors.grey.shade200, width: sel ? 2 : 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(cat['emoji'] as String, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(cat['label'] as String, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12, color: sel ? clr : Colors.grey.shade600)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _label('REMINDER INTERVAL'),
                const SizedBox(height: 8),
                ...intervalOptions.map((opt) {
                  final hours = opt['hours'] as int;
                  final sel = selectedInterval == hours;
                  return GestureDetector(
                    onTap: () => setD(() => selectedInterval = hours),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? const Color(0xFF43A047) : Colors.grey.shade200, width: sel ? 2 : 1),
                      ),
                      child: Row(children: [
                        Text(opt['label'] as String, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: sel ? const Color(0xFF1B5E20) : Colors.grey.shade700)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(opt['sub'] as String, style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500))),
                        if (sel) const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047), size: 16),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection('users').doc(uid).collection('habits')
                    .doc(widget.docId)
                    .update({'habitName': name, 'category': selectedCat, 'intervalHours': selectedInterval});
                if (!dCtx.mounted) return;
                Navigator.pop(dCtx);
              },
              child: Text('Save', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ──
  void _delete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Demolish?', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
        content: Text('Remove "${widget.habitName}" from your city?\nThis cannot be undone.',
            style: GoogleFonts.nunito(color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users').doc(uid).collection('habits')
                  .doc(widget.docId).delete();
            },
            child: Text('Demolish 🏚️', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Action bottom sheet ──
  void _showActions(BuildContext ctx) {
    final parentCtx = ctx;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Image.asset(_assetPath(), width: 38,
                    errorBuilder: (_, __, ___) => Text(_emoji, style: const TextStyle(fontSize: 28)))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.habitName, style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                Text('$_emoji ${widget.category.replaceAll('_', ' ')}  •  ${_isMax ? "MAX ⭐" : "Level ${widget.level}"}',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500)),
              ])),
            ]),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Mark Complete Today',
              sublabel: 'Build your streak 🔥',
              color: const Color(0xFF2E7D32),
              onTap: () { Navigator.pop(ctx); _complete(parentCtx); },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.edit_rounded,
              label: 'Edit Habit',
              sublabel: 'Rename, change type or frequency',
              color: const Color(0xFF1E88E5),
              onTap: () { Navigator.pop(ctx); _edit(parentCtx); },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Demolish Building',
              sublabel: 'Remove this habit permanently',
              color: Colors.red.shade600,
              onTap: () { Navigator.pop(ctx); _delete(parentCtx); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: GoogleFonts.nunito(
      fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF388E3C), letterSpacing: 1.5));

  SnackBar _snack(String msg, Color bg, {int duration = 2}) => SnackBar(
    content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: duration),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    final imgSize = (widget.tileSize * 0.50).clamp(32.0, 64.0);

    return GestureDetector(
      onTap: () => _showActions(context),
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (_, child) => Transform.translate(offset: Offset(0, _bounceAnim.value), child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            boxShadow: isGlowing
                ? [BoxShadow(color: _color.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 3)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Level badge
              Container(
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _isMax ? Colors.amber.shade700 : _color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Text(
                  _isMax ? 'MAX ⭐' : 'Lvl ${widget.level}',
                  style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              // Building image
              Image.asset(
                _assetPath(),
                width: imgSize, height: imgSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.apartment_rounded, size: imgSize, color: _color),
              ),
              // Ground shadow
              Container(
                width: imgSize * 0.7,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: RadialGradient(
                    colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 1),
              // Name label
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  widget.habitName,
                  style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action tile ──
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.sublabel, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(sublabel, style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}