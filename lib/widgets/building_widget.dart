import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

class BuildingWidget extends StatefulWidget {
  final String habitName;
  final String category;
  final String docId;
  final int level;
  final double tileWidth;

  const BuildingWidget({
    super.key,
    required this.habitName,
    required this.category,
    required this.docId,
    required this.level,
    required this.tileWidth,
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
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  String _assetPath() {
    int lvl = widget.level.clamp(0, 2);
    if (widget.category == 'work') lvl = 0;
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

  // ── Complete habit for today ──
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
    final last = (d['lastCompleted'] as Timestamp).toDate();
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(ctx);

    if (last.year == now.year && last.month == now.month && last.day == now.day) {
      messenger.showSnackBar(_snack('✅  Already done today!', const Color(0xFF388E3C)));
      return;
    }

    final newStreak = (d['streak'] as int) + 1;
    final newLevel = (newStreak ~/ 3).clamp(0, 2);
    await ref.update({'streak': newStreak, 'level': newLevel, 'lastCompleted': now});
    if (!mounted) return;

    if (newLevel > widget.level) {
      messenger.showSnackBar(_snack('🎉  ${widget.habitName} leveled up! → Lvl $newLevel',
          Colors.orange.shade700, duration: 3));
    } else {
      messenger.showSnackBar(
          _snack('🔥  ${widget.habitName}  •  Streak: $newStreak', const Color(0xFF2E7D32)));
    }
  }

  // ── Edit dialog ──
  void _edit(BuildContext ctx) {
    final ctrl = TextEditingController(text: widget.habitName);
    String selectedCat = widget.category;
    const cats = [
      {'value': 'workout',          'label': 'Workout',     'emoji': '🏋️', 'color': 0xFFE53935},
      {'value': 'study',            'label': 'Study',       'emoji': '📚', 'color': 0xFF1E88E5},
      {'value': 'work',             'label': 'Work',        'emoji': '🏢', 'color': 0xFF546E7A},
      {'value': 'self_improvement', 'label': 'Self Growth', 'emoji': '🌱', 'color': 0xFF43A047},
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
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF2E7D32), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Edit Habit',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFF1B5E20))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('HABIT NAME',
                  style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: const Color(0xFF388E3C), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF1F8E9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF43A047), width: 2)),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text('BUILDING TYPE',
                  style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: const Color(0xFF388E3C), letterSpacing: 1.5)),
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
                        border: Border.all(color: sel ? clr : Colors.grey.shade200,
                            width: sel ? 2 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cat['emoji'] as String,
                            style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(cat['label'] as String,
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: sel ? clr : Colors.grey.shade600)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(
                      color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection('users').doc(uid).collection('habits')
                    .doc(widget.docId)
                    .update({'habitName': name, 'category': selectedCat});
                if (!dCtx.mounted) return;
                Navigator.pop(dCtx);
              },
              child: Text('Save',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.w800)),
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
      // Use 'dialogCtx' — the dialog's own context — for all Navigator.pop calls.
      // Using the parent 'ctx' after the widget is deleted from Firestore causes
      // the widget to unmount, making ctx.mounted false and crashing on pop.
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Demolish?',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
        content: Text(
            'Remove "${widget.habitName}" from your city?\nThis cannot be undone.',
            style: GoogleFonts.nunito(color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.nunito(
                    color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // Close dialog first, THEN delete — avoids mounted check issues
              Navigator.pop(dialogCtx);
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('users').doc(uid).collection('habits')
                  .doc(widget.docId).delete();
            },
            child: Text('Demolish 🏚️',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Action bottom sheet (tap on building) ──
  void _showActions(BuildContext ctx) {
    // Save parent context before sheet opens.
    // Sheet ctx becomes invalid after Navigator.pop — use parentCtx for all post-pop actions.
    final parentCtx = ctx;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            // Building preview header
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Image.asset(
                    _assetPath(),
                    width: 38,
                    errorBuilder: (_, __, ___) =>
                        Text(_emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.habitName,
                        style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B5E20))),
                    Text('$_emoji ${widget.category.replaceAll('_', ' ')}  •  Level ${widget.level}',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 8),
            // Actions
            _ActionTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Mark Complete Today',
              sublabel: 'Build your streak 🔥',
              color: const Color(0xFF2E7D32),
              onTap: () {
                Navigator.pop(ctx);
                _complete(parentCtx);
              },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.edit_rounded,
              label: 'Edit Habit',
              sublabel: 'Rename or change type',
              color: const Color(0xFF1E88E5),
              onTap: () {
                Navigator.pop(ctx);
                _edit(parentCtx);
              },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Demolish Building',
              sublabel: 'Remove this habit permanently',
              color: Colors.red.shade600,
              onTap: () {
                Navigator.pop(ctx);
                _delete(parentCtx);
              },
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snack(String msg, Color bg, {int duration = 2}) => SnackBar(
    content: Text(msg,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: duration),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    final imgSize = (widget.tileWidth * 0.55).clamp(50.0, 90.0);

    return GestureDetector(
      onTap: () => _showActions(context),
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, _bounceAnim.value), child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            boxShadow: isGlowing
                ? [BoxShadow(color: _color.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 3)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Level badge
              if (widget.level > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('Lvl ${widget.level} ⭐',
                      style: GoogleFonts.nunito(
                          fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),

              // Building image (YOUR assets)
              Image.asset(
                _assetPath(),
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.apartment_rounded,
                    size: imgSize, color: _color),
              ),

              const SizedBox(height: 3),

              // Habit name label
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$_emoji ${widget.habitName}',
                  style: GoogleFonts.nunito(
                      fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
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

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              Text(sublabel,
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}