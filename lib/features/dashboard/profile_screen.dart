import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFFE8F5E9)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, userSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('habits')
                    .snapshots(),
                builder: (context, habitSnap) {
                  final user = userSnap.data?.data() as Map<String, dynamic>?;
                  final habits = habitSnap.data?.docs ?? [];

                  int totalStreak = 0;
                  int maxStreak = 0;
                  Map<String, int> categoryCount = {};

                  for (var doc in habits) {
                    final data = doc.data() as Map<String, dynamic>;
                    final streak = data["streak"] as int? ?? 0;
                    totalStreak += streak;
                    if (streak > maxStreak) maxStreak = streak;
                    final cat = data["category"] as String;
                    categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // ── Avatar + Name ──
                        _buildAvatarSection(user),

                        const SizedBox(height: 28),

                        // ── Stats Cards ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _statCard("🏙️", "${habits.length}", "Buildings", const Color(0xFF43A047)),
                              const SizedBox(width: 12),
                              _statCard("🔥", "$totalStreak", "Total Streak", const Color(0xFFE53935)),
                              const SizedBox(width: 12),
                              _statCard("⭐", "$maxStreak", "Best Streak", const Color(0xFFFFA000)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Profile Info Card ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.person_pin_rounded,
                                          color: Color(0xFF2E7D32), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Personal Details",
                                      style: GoogleFonts.nunito(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                if (user != null) ...[
                                  _infoRow(Icons.badge_outlined, "Name", user['name'] ?? '-'),
                                  _divider(),
                                  _infoRow(Icons.cake_outlined, "Age", "${user['age'] ?? '-'} years"),
                                  _divider(),
                                  _infoRow(Icons.phone_outlined, "Phone", user['phone'] ?? '-'),
                                  _divider(),
                                  _infoRow(Icons.email_outlined, "Email", user['email'] ?? '-'),
                                  _divider(),
                                  _infoRow(
                                    Icons.calendar_today_outlined,
                                    "Member Since",
                                    user['createdAt'] != null
                                        ? _formatDate((user['createdAt'] as Timestamp).toDate())
                                        : '-',
                                  ),
                                ] else
                                  const Center(child: CircularProgressIndicator()),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── District Breakdown ──
                        if (categoryCount.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.map_outlined,
                                            color: Color(0xFF2E7D32), size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        "City Districts",
                                        style: GoogleFonts.nunito(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...categoryCount.entries.map(
                                        (e) => _districtRow(e.key, e.value, habits.length),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Sign Out ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade200, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Sign Out",
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Map<String, dynamic>? user) {
    final name = user?['name'] as String? ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      children: [
        // Avatar circle
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.nunito(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          "City Builder",
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF43A047), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 1);

  Widget _districtRow(String category, int count, int total) {
    final data = _categoryMeta(category);
    final pct = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(data["emoji"] as String, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                data["label"] as String,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const Spacer(),
              Text(
                "$count building${count > 1 ? 's' : ''}",
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(data["color"] as Color),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _categoryMeta(String cat) {
    switch (cat) {
      case "workout":
        return {"emoji": "🏋️", "label": "Workout District", "color": const Color(0xFFE53935)};
      case "study":
        return {"emoji": "📚", "label": "Study District", "color": const Color(0xFF1E88E5)};
      case "work":
        return {"emoji": "🏢", "label": "Work District", "color": const Color(0xFF546E7A)};
      default:
        return {"emoji": "🌱", "label": "Self Growth District", "color": const Color(0xFF43A047)};
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }
}