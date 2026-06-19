import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../services/supabase_service.dart';
import '../../services/cart_service.dart';
import '../../services/theme_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profileData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final data = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _profileData = data;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    // Clear local cart memory so next user starts fresh
    CartService.clearLocalCart();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = Supabase.instance.client.auth.currentUser;
    final String email = user?.email ?? 'guest@bobupizza.com';
    final String name = _profileData?['full_name'] ?? user?.userMetadata?['full_name'] ??
        email.split('@').first;
    final String initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'BP';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoadingProfile 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
              // Header card
              _buildProfileHeader(name, email, initials, scale),

              SizedBox(height: 24 * scale),

              // Stats row
              _buildStatsRow(scale, theme, isDark),

              SizedBox(height: 24 * scale),

              // Menu sections
              _buildSection(
                'Account',
                [
                  _MenuItem(Icons.person_outline_rounded,    'Edit Profile',        false),
                  _MenuItem(Icons.location_on_outlined,      'Saved Addresses',     false),
                  _MenuItem(Icons.payment_outlined,          'Payment Methods',     false),
                ],
                scale,
                context,
                theme,
                isDark,
              ),

              SizedBox(height: 16 * scale),

              _buildSection(
                'Preferences',
                [
                  _MenuItem(Icons.notifications_none_rounded, 'Notifications',     false),
                  _MenuItem(Icons.language_rounded,            'Language',          false),
                  _MenuItem(Icons.dark_mode_outlined,          'Dark Mode',         true),
                ],
                scale,
                context,
                theme,
                isDark,
              ),

              SizedBox(height: 16 * scale),

              _buildSection(
                'Support',
                [
                  _MenuItem(Icons.help_outline_rounded,        'Help & FAQ',        false),
                  _MenuItem(Icons.privacy_tip_outlined,        'Privacy Policy',    false),
                  _MenuItem(Icons.star_outline_rounded,        'Rate the App',      false),
                ],
                scale,
                context,
                theme,
                isDark,
              ),

              SizedBox(height: 16 * scale),

              // Sign out
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: GestureDetector(
                  onTap: () => _signOut(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 15 * scale),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Colors.red[400], size: 20 * scale),
                        SizedBox(width: 8 * scale),
                        Text(
                          'Sign Out',
                          style: GoogleFonts.poppins(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16 * scale),

              // App version
              Text(
                'Bobu Pizza v1.0.0',
                style: GoogleFonts.poppins(
                  fontSize: 11 * scale,
                  color: isDark ? Colors.white30 : const Color(0xFF2D1A0E).withOpacity(0.3),
                ),
              ),

              SizedBox(height: 100 * scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      String name, String email, String initials, double scale) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16 * scale),
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC0392B), Color(0xFFE74C3C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.poppins(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16 * scale),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 12 * scale,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🍕 Pizza Lover',
                    style: GoogleFonts.poppins(
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double scale, ThemeData theme, bool isDark) {
    final stats = [
      {'label': 'Orders',    'value': '12'},
      {'label': 'Favourites','value': '5'},
      {'label': 'Reviews',   'value': '3'},
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                  right: s != stats.last ? 10 * scale : 0),
              padding: EdgeInsets.symmetric(vertical: 14 * scale),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: const Color(0xFF2D1A0E).withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    s['value']!,
                    style: GoogleFonts.poppins(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    s['label']!,
                    style: GoogleFonts.poppins(
                      fontSize: 11 * scale,
                      color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(String title, List<_MenuItem> items,
      double scale, BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4 * scale, bottom: 10 * scale),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withOpacity(0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: const Color(0xFF2D1A0E).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (item.label == 'Saved Addresses') {
                          Navigator.pushNamed(context, '/addresses');
                        } else if (item.label == 'Edit Profile') {
                          final result = await Navigator.pushNamed(context, '/edit-profile');
                          if (result == true) {
                            _fetchProfile();
                          }
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 14 * scale),
                        child: Row(
                          children: [
                            Container(
                              width: 36 * scale,
                              height: 36 * scale,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.icon,
                                  color: AppColors.primary,
                                  size: 18 * scale),
                            ),
                            SizedBox(width: 14 * scale),
                            Expanded(
                              child: Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                                ),
                              ),
                            ),
                            if (item.hasToggle)
                              Switch(
                                value: ThemeService().isDarkMode,
                                onChanged: (val) {
                                  ThemeService().toggleTheme();
                                },
                                activeTrackColor: AppColors.primary,
                                materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white24 : const Color(0xFF2D1A0E)
                                    .withOpacity(0.3),
                                size: 20 * scale,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : const Color(0xFF2D1A0E).withOpacity(0.06),
                        indent: 16 * scale,
                        endIndent: 16 * scale,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final bool hasToggle;
  const _MenuItem(this.icon, this.label, this.hasToggle);
}