import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      body: Column(
        children: [
          // ── PINNED HEADER — always on top ──
          _PinnedHeader(uid: uid),

          // ── Scrollable body ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('habits')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  );
                }
                final habits = snap.data!.docs;
                if (habits.isEmpty) return _EmptyState();

                final now = DateTime.now();
                int totalStreak = 0, maxStreak = 0, completedToday = 0, totalLevel = 0;
                final Map<String, List<Map<String, dynamic>>> byCategory = {};

                for (final doc in habits) {
                  final d = doc.data() as Map<String, dynamic>;
                  final streak = d['streak'] as int? ?? 0;
                  final level  = d['level']  as int? ?? 0;
                  final cat    = d['category'] as String? ?? 'self_improvement';
                  final last   = (d['lastCompleted'] as Timestamp?)?.toDate() ?? now;
                  final name   = d['habitName'] as String? ?? cat;

                  totalStreak += streak;
                  if (streak > maxStreak) maxStreak = streak;
                  totalLevel += level;
                  final doneToday = last.year == now.year &&
                      last.month == now.month && last.day == now.day;
                  if (doneToday) completedToday++;

                  byCategory.putIfAbsent(cat, () => []);
                  byCategory[cat]!.add({
                    'name': name, 'streak': streak, 'level': level,
                    'doneToday': doneToday, 'lastCompleted': last,
                  });
                }

                final total = habits.length;
                final cityHealth = total == 0 ? 0.0 : completedToday / total;
                final avgStreak  = total == 0 ? 0.0 : totalStreak / total;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // City Health
                    _SectionLabel('🏥  City Health Today'),
                    const SizedBox(height: 10),
                    _CityHealthBar(health: cityHealth, completed: completedToday, total: total),
                    const SizedBox(height: 22),

                    // Overview tiles
                    _SectionLabel('📊  Overview'),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _StatTile(emoji: '🏗️', value: '$total',
                            label: 'Total Habits',  color: const Color(0xFF43A047)),
                        _StatTile(emoji: '🔥', value: avgStreak.toStringAsFixed(1),
                            label: 'Avg Streak',   color: const Color(0xFFE53935)),
                        _StatTile(emoji: '🏆', value: '$maxStreak',
                            label: 'Best Streak',  color: const Color(0xFFFFA000)),
                        _StatTile(emoji: '⭐', value: '$totalLevel',
                            label: 'Total Levels', color: const Color(0xFF1E88E5)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Districts
                    _SectionLabel('🗺️  Districts'),
                    const SizedBox(height: 12),
                    ...byCategory.entries.map((e) =>
                        _DistrictCard(category: e.key, habits: e.value)),
                    const SizedBox(height: 8),

                    // All habits
                    _SectionLabel('📋  All Habits'),
                    const SizedBox(height: 12),
                    ...habits.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final last = (d['lastCompleted'] as Timestamp?)?.toDate() ?? now;
                      final doneToday = last.year == now.year &&
                          last.month == now.month && last.day == now.day;
                      return _HabitRow(
                        name: d['habitName'] as String? ?? d['category'],
                        category: d['category'] as String? ?? 'self_improvement',
                        streak: d['streak'] as int? ?? 0,
                        level: d['level'] as int? ?? 0,
                        doneToday: doneToday,
                        daysMissed: now.difference(last).inDays,
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PINNED HEADER
// ─────────────────────────────────────────────
class _PinnedHeader extends StatelessWidget {
  final String uid;
  const _PinnedHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('habits').snapshots(),
      builder: (context, snap) {
        final habits = snap.data?.docs ?? [];
        final now = DateTime.now();
        int completed = 0;
        for (final doc in habits) {
          final d = doc.data() as Map<String, dynamic>;
          final last = (d['lastCompleted'] as Timestamp?)?.toDate() ?? now;
          if (last.year == now.year && last.month == now.month && last.day == now.day) {
            completed++;
          }
        }
        final total = habits.length;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('City Report',
                                style: GoogleFonts.nunito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text('Track your city\'s growth',
                                style: GoogleFonts.nunito(
                                    fontSize: 13, color: Colors.white60)),
                          ],
                        ),
                      ),
                      // Live today badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              total == 0 ? '—' : '$completed/$total',
                              style: GoogleFonts.nunito(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            ),
                            Text('today',
                                style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 14),
                    // Mini progress bar across header
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : completed / total,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${((completed / total) * 100).toInt()}%',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w900,
          color: const Color(0xFF1B5E20)));
}

// ─────────────────────────────────────────────
// CITY HEALTH BAR
// ─────────────────────────────────────────────
class _CityHealthBar extends StatelessWidget {
  final double health;
  final int completed, total;
  const _CityHealthBar({required this.health, required this.completed, required this.total});

  Color get _color {
    if (health >= 0.8) return const Color(0xFF2E7D32);
    if (health >= 0.5) return const Color(0xFFFFA000);
    return const Color(0xFFE53935);
  }

  String get _status {
    if (total == 0) return 'Add habits to see city health';
    if (health == 1.0) return '🌟 Thriving city! All done!';
    if (health >= 0.7) return '🏙️ City is doing well';
    if (health >= 0.4) return '🌥️ Some districts need attention';
    return '⚠️ City is decaying — complete your habits!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(_status,
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700)),
            ),
            Text('${(health * 100).toInt()}%',
                style: GoogleFonts.nunito(
                    fontSize: 24, fontWeight: FontWeight.w900, color: _color)),
          ],
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: health),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, val, __) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 14,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// STAT TILE
// ─────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _StatTile({required this.emoji, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DISTRICT CARD
// ─────────────────────────────────────────────
class _DistrictCard extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> habits;
  const _DistrictCard({required this.category, required this.habits});

  Map<String, dynamic> get _meta {
    switch (category) {
      case 'workout':
        return {'emoji': '🏋️', 'label': 'Workout District',   'color': const Color(0xFFE53935), 'bg': const Color(0xFFFFF3F3)};
      case 'study':
        return {'emoji': '📚', 'label': 'Study District',     'color': const Color(0xFF1E88E5), 'bg': const Color(0xFFF0F6FF)};
      case 'work':
        return {'emoji': '🏢', 'label': 'Work District',      'color': const Color(0xFF546E7A), 'bg': const Color(0xFFF0F4F6)};
      default:
        return {'emoji': '🌱', 'label': 'Self Growth District','color': const Color(0xFF43A047), 'bg': const Color(0xFFF0F7F0)};
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    final color = m['color'] as Color;
    final doneCount = habits.where((h) => h['doneToday'] as bool).length;
    final totalStreak = habits.fold<int>(0, (s, h) => s + (h['streak'] as int));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: m['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(m['emoji'] as String, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(m['label'] as String,
              style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$doneCount/${habits.length} today',
                style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 12),
        ...habits.map((h) {
          final streak = h['streak'] as int;
          final level  = h['level']  as int;
          final done   = h['doneToday'] as bool;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : Colors.grey.shade200,
                ),
                child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(h['name'] as String,
                    style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
              ),
              Text('🔥 $streak',
                  style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Lvl $level',
                    style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Combined streak',
              style: GoogleFonts.nunito(
                  fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          Text('$totalStreak days',
              style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (totalStreak / (habits.length * 30)).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// HABIT ROW
// ─────────────────────────────────────────────
class _HabitRow extends StatelessWidget {
  final String name, category;
  final int streak, level, daysMissed;
  final bool doneToday;
  const _HabitRow({
    required this.name, required this.category,
    required this.streak, required this.level,
    required this.doneToday, required this.daysMissed,
  });

  Color get _color {
    switch (category) {
      case 'workout': return const Color(0xFFE53935);
      case 'study':   return const Color(0xFF1E88E5);
      case 'work':    return const Color(0xFF546E7A);
      default:        return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doneToday ? _color.withValues(alpha: 0.35) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20))),
        ),
        if (!doneToday && daysMissed > 1)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text('$daysMissed d missed',
                style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
          ),
        Text('🔥 $streak',
            style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
        const SizedBox(width: 8),
        Icon(
          doneToday ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: doneToday ? _color : Colors.grey.shade300,
          size: 22,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📊', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('No habits yet',
            style: GoogleFonts.nunito(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: const Color(0xFF1B5E20))),
        const SizedBox(height: 6),
        Text('Go to My City and add some habits!',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade500)),
      ]),
    );
  }
}