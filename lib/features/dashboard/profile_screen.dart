import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../authentication/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editMode = false;

  final _nameCtrl  = TextEditingController();
  final _ageCtrl   = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(String uid) async {
    final name  = _nameCtrl.text.trim();
    final age   = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name':  name,
      'age':   age,
      'phone': phone,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() => _editMode = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile saved!', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final uid  = user.uid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFFE8F5E9)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, userSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('habits').snapshots(),
                builder: (context, habitSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>?;
                  final habits   = habitSnap.data?.docs ?? [];

                  // Pre-fill controllers when not in edit mode and data arrived
                  if (!_editMode && userData != null) {
                    if (_nameCtrl.text.isEmpty)  _nameCtrl.text  = userData['name']  ?? '';
                    if (_ageCtrl.text.isEmpty)   _ageCtrl.text   = '${userData['age'] ?? ''}';
                    if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = userData['phone'] ?? '';
                  }

                  int totalStreak = 0, maxStreak = 0;
                  final Map<String, int> catCount = {};
                  for (final doc in habits) {
                    final d = doc.data() as Map<String, dynamic>;
                    final s = (d['streak'] as int?) ?? 0;
                    totalStreak += s;
                    if (s > maxStreak) maxStreak = s;
                    final cat = d['category'] as String;
                    catCount[cat] = (catCount[cat] ?? 0) + 1;
                  }

                  final profileMissing = userData == null || (userData['name'] as String?)?.isEmpty == true;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // ── Complete Profile Banner ──
                        if (profileMissing)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Complete your profile to get started!',
                                    style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                                GestureDetector(
                                  onTap: () => setState(() => _editMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                    child: Text('Fill In', style: GoogleFonts.nunito(color: Colors.amber.shade800, fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                ),
                              ]),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // ── Avatar + Name ──
                        _buildAvatarSection(userData, user),

                        const SizedBox(height: 28),

                        // ── Stats ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            _statCard('🏙️', '${habits.length}', 'Buildings', const Color(0xFF43A047)),
                            const SizedBox(width: 12),
                            _statCard('🔥', '$totalStreak', 'Total Streak', const Color(0xFFE53935)),
                            const SizedBox(width: 12),
                            _statCard('⭐', '$maxStreak', 'Best Streak', const Color(0xFFFFA000)),
                          ]),
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
                              boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.person_pin_rounded, color: Color(0xFF2E7D32), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Personal Details', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(() => _editMode = !_editMode),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _editMode ? const Color(0xFF2E7D32) : const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(_editMode ? Icons.close_rounded : Icons.edit_rounded,
                                            color: _editMode ? Colors.white : const Color(0xFF2E7D32), size: 14),
                                        const SizedBox(width: 4),
                                        Text(_editMode ? 'Cancel' : 'Edit',
                                            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800,
                                                color: _editMode ? Colors.white : const Color(0xFF2E7D32))),
                                      ]),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 18),

                                if (_editMode) ...[
                                  // ── Edit Fields ──
                                  _editField('Full Name', _nameCtrl, Icons.badge_outlined),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(child: _editField('Age', _ageCtrl, Icons.cake_outlined, keyboardType: TextInputType.number)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _editField('Phone', _phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone)),
                                  ]),
                                  const SizedBox(height: 18),
                                  GestureDetector(
                                    onTap: () => _saveProfile(uid),
                                    child: Container(
                                      width: double.infinity,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(child: Text('Save Changes', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white))),
                                    ),
                                  ),
                                ] else if (userData != null) ...[
                                  _infoRow(Icons.badge_outlined,    'Name',    userData['name'] ?? '-'),
                                  _divider(),
                                  _infoRow(Icons.cake_outlined,     'Age',     '${userData['age'] ?? '-'} years'),
                                  _divider(),
                                  _infoRow(Icons.phone_outlined,    'Phone',   userData['phone'] ?? '-'),
                                  _divider(),
                                  _infoRow(Icons.email_outlined,    'Email',   userData['email'] ?? user.email ?? '-'),
                                  _divider(),
                                  _infoRow(Icons.calendar_today_outlined, 'Member Since',
                                    userData['createdAt'] != null
                                        ? _formatDate((userData['createdAt'] as dynamic).toDate() as DateTime)
                                        : '-'),
                                ] else
                                  const Center(child: CircularProgressIndicator()),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── City Districts ──
                        if (catCount.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.map_outlined, color: Color(0xFF2E7D32), size: 20)),
                                    const SizedBox(width: 10),
                                    Text('City Districts', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20))),
                                  ]),
                                  const SizedBox(height: 16),
                                  ...catCount.entries.map((e) => _districtRow(e.key, e.value, habits.length)),
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
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade200, width: 1.5),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Text('Sign Out', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red.shade600)),
                              ]),
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

  Widget _buildAvatarSection(Map<String, dynamic>? userData, User fireUser) {
    final name    = userData?['name'] as String? ?? fireUser.displayName ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final photoUrl = fireUser.photoURL;

    return Column(children: [
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: ClipOval(
          child: photoUrl != null
              ? Image.network(photoUrl, fit: BoxFit.cover)
              : Center(child: Text(initial, style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFF1B5E20)))),
        ),
      ),
      const SizedBox(height: 12),
      Text(name, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
      Text('City Builder', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60, letterSpacing: 1.5)),
    ]);
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF43A047), size: 18),
          filled: true, fillColor: const Color(0xFFF1F8E9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF43A047), width: 2)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    ]);
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF43A047), size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.5)),
          Text(value, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20))),
        ]),
      ]),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 1);

  Widget _districtRow(String category, int count, int total) {
    final meta = _catMeta(category);
    final pct  = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(meta['emoji'] as String, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(meta['label'] as String, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1B5E20))),
          const Spacer(),
          Text('$count building${count > 1 ? 's' : ''}', style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(meta['color'] as Color)),
        ),
      ]),
    );
  }

  Map<String, dynamic> _catMeta(String cat) {
    switch (cat) {
      case 'workout': return {'emoji': '🏋️', 'label': 'Workout District',   'color': const Color(0xFFE53935)};
      case 'study':   return {'emoji': '📚', 'label': 'Study District',     'color': const Color(0xFF1E88E5)};
      case 'work':    return {'emoji': '🏢', 'label': 'Work District',      'color': const Color(0xFF546E7A)};
      default:        return {'emoji': '🌱', 'label': 'Self Growth District','color': const Color(0xFF43A047)};
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}