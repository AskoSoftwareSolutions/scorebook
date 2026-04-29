import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../services/subscription_service.dart';
import '../../services/ad_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _svc  = SubscriptionService();

  SubscriptionInfo? _sub;
  String _appVersion = '1.0.0';
  bool   _loadingProfile = false;

  // Editable profile
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool   _editingProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // App version
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {}

    // Subscription
    if (_auth.currentUser != null) {
      final sub = await _svc.loadSubscription();
      if (mounted) {
        setState(() {
          _sub = sub;
          _nameCtrl.text  = sub?.name  ?? '';
          _emailCtrl.text = sub?.email ?? '';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loadingProfile = true);
    await _svc.updateProfile(
      name:  name,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loadingProfile   = false;
      _editingProfile   = false;
    });
    Get.snackbar('Saved', 'Profile updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.primary,
        colorText: Colors.white);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Logout',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
            'Are you sure you want to logout?\nYour subscription will remain active.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Logout',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.signOut();
      AdService().setAdsEnabled(true); // re-enable ads after logout
      setState(() => _sub = null);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showTermsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TermsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user    = _auth.currentUser;
    final isLoggedIn = user != null;
    final hasActiveSub = _sub != null && _sub!.isActive;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textPrimary),
            onPressed: () => Get.back(),
          ),
          title: const Text('Settings',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── ACCOUNT SECTION ─────────────────────────────────────────
              _SectionHeader(label: 'ACCOUNT'),

              if (!isLoggedIn)
                _SettingsTile(
                  icon: Icons.login_rounded,
                  iconBg: AppTheme.primary,
                  title: 'Login',
                  subtitle: 'Sign in with mobile number',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  onTap: () async {
                    await Get.toNamed(AppRoutes.login);
                    _load(); // refresh after login
                  },
                )
              else ...[
                // Profile card
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.greenGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (_sub?.name.isNotEmpty == true)
                                  ? _sub!.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sub?.name.isNotEmpty == true
                                    ? _sub!.name
                                    : 'Set your name',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                user.phoneNumber ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _editingProfile
                                ? Icons.close_rounded
                                : Icons.edit_rounded,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _editingProfile = !_editingProfile),
                        ),
                      ]),

                      if (_editingProfile) ...[
                        const SizedBox(height: 14),
                        _InlineField(
                            label: 'Name',
                            controller: _nameCtrl,
                            hint: 'Your name'),
                        const SizedBox(height: 10),
                        _InlineField(
                            label: 'Email',
                            controller: _emailCtrl,
                            hint: 'Email (optional)',
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _loadingProfile ? null : _saveProfile,
                            child: _loadingProfile
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                                : const Text('Save',
                                style:
                                TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                _SettingsTile(
                  icon: Icons.logout_rounded,
                  iconBg: AppTheme.error,
                  title: 'Logout',
                  subtitle: 'Sign out from this device',
                  onTap: _logout,
                ),
              ],

              const SizedBox(height: 8),

              // ── SUBSCRIPTION SECTION ─────────────────────────────────────
              _SectionHeader(label: 'SUBSCRIPTION'),

              // Ads-Free tile
              _SettingsTile(
                icon: hasActiveSub
                    ? Icons.verified_rounded
                    : Icons.block_rounded,
                iconBg: hasActiveSub ? AppTheme.primary : AppTheme.warning,
                title: 'Ads Free',
                subtitle: hasActiveSub
                    ? '${_sub!.daysLeft}  ·  Expires ${_sub!.expireFormatted}'
                    : 'Subscribe to remove all ads',
                trailingBadge: hasActiveSub ? 'ACTIVE' : 'GET NOW',
                trailingBadgeColor: hasActiveSub
                    ? AppTheme.primaryLight
                    : AppTheme.warning,
                trailing: hasActiveSub
                    ? null
                    : const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.textSecondary),
                onTap: hasActiveSub
                    ? null
                    : () async {
                  // Must be logged in to subscribe
                  if (!isLoggedIn) {
                    await Get.toNamed(AppRoutes.login,
                        parameters: {'next': 'subscription'});
                    _load();
                  } else {
                    await Get.toNamed(AppRoutes.subscription);
                    _load();
                  }
                },
              ),

              if (hasActiveSub) ...[
                const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.primaryLight, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Plan: ${_sub!.planLabel}  ·  Started ${_sub!.startDate.day}/'
                            '${_sub!.startDate.month}/${_sub!.startDate.year}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 8),

              // ── APP SECTION ──────────────────────────────────────────────
              _SectionHeader(label: 'APP'),

              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFF1565C0),
                title: 'App Version',
                subtitle: _appVersion,
              ),

              _SettingsTile(
                icon: Icons.description_rounded,
                iconBg: const Color(0xFF4A148C),
                title: 'Terms & Conditions',
                subtitle: 'Rules for using ScoreBook',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.textSecondary),
                onTap: () => _showTermsSheet(context),
              ),

              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                iconBg: const Color(0xFF37474F),
                title: 'Privacy Policy',
                subtitle: 'How we use your data',
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppTheme.textSecondary),
                onTap: () async {
                  final url = Uri.parse(
                      'https://doc-hosting.flycricket.io/scorebook-privacy-policy/4a50064f-256c-4402-b866-559c8a8a2734/privacy');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    Get.snackbar('Could not open',
                        'Please visit the URL manually:\n${url.toString()}',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppTheme.error,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 4));
                  }
                },
              ),

              const SizedBox(height: 24),

              // ── Footer ───────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text('🏏',
                        style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    const Text('ScoreBook',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 2),
                    Text('v$_appVersion',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '© ${DateTime.now().year} ScoreBook. All rights reserved.',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData   icon;
  final Color      iconBg;
  final String     title;
  final String     subtitle;
  final Widget?    trailing;
  final String?    trailingBadge;
  final Color?     trailingBadgeColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingBadge,
    this.trailingBadgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          // Trailing badge or icon
          if (trailingBadge != null)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (trailingBadgeColor ?? AppTheme.primaryLight)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: (trailingBadgeColor ?? AppTheme.primaryLight)
                        .withOpacity(0.4)),
              ),
              child: Text(
                trailingBadge!,
                style: TextStyle(
                  color: trailingBadgeColor ?? AppTheme.primaryLight,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (trailing != null)
            trailing!,
        ]),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _InlineField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          )),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12),
          filled: true,
          fillColor: AppTheme.bgSurface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: AppTheme.primaryLight, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TERMS & CONDITIONS SHEET
//
// In-app, fully self-contained — no external hosting needed. The text below
// reflects ScoreBook's actual feature set: local SQLite scoring, Firebase
// cloud sharing with 14-day retention, AdMob ads, and optional ad-free
// subscriptions. Update the "Last updated" date whenever you revise this.
// ─────────────────────────────────────────────────────────────────────────────
class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  static const String _lastUpdated = 'April 26, 2026';
  static const String _supportEmail = 'askosoftwaresolutions@gmail.com';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Color(0xFF4A148C), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms & Conditions',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                      Text('Please read carefully before using ScoreBook',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              height: 1.3)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: () => Get.back(),
                ),
              ]),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: const [
                  _TermsMeta(label: 'Effective date', value: _lastUpdated),
                  SizedBox(height: 18),

                  _TermsSection(
                    n: 1,
                    title: 'Acceptance of Terms',
                    body:
                        'By downloading, installing or using ScoreBook ("the App"), '
                        'you agree to be bound by these Terms & Conditions. If you '
                        'do not agree, please uninstall the App.',
                  ),
                  _TermsSection(
                    n: 2,
                    title: 'About ScoreBook',
                    body:
                        'ScoreBook is a cricket scoring app that lets you create '
                        'matches, record ball-by-ball scoring, manage tournaments, '
                        'share live scores with viewers via a code + password, and '
                        'view detailed post-match summaries. Most features work '
                        'fully offline; cloud sharing requires an internet '
                        'connection.',
                  ),
                  _TermsSection(
                    n: 3,
                    title: 'Account & Login',
                    body:
                        'Some features (subscriptions, scheduled tournament '
                        'matches, joining as a co-scorer) require you to log in '
                        'using your mobile number and OTP via Firebase '
                        'Authentication. You are responsible for keeping your '
                        'phone number and any match passwords secure.',
                  ),
                  _TermsSection(
                    n: 4,
                    title: 'Match Data & Cloud Sync',
                    body:
                        'Match data you create stays on your device by default. '
                        'When you share a match for live viewing or hand it over '
                        'to another scorer, the match data (scores, players, ball '
                        'log) is uploaded to Firebase Realtime Database. Cloud '
                        'match data is automatically purged after 14 days. You '
                        'retain ownership of your match data; we only store and '
                        'transmit it to deliver the sharing features.',
                  ),
                  _TermsSection(
                    n: 5,
                    title: 'Subscriptions & Payments',
                    body:
                        'We offer optional ad-free subscriptions (3 months for '
                        '₹39, 1 year for ₹100). Subscriptions are non-refundable '
                        'and auto-expire at the end of the chosen term. There is '
                        'no auto-renewal — you must purchase a new plan to '
                        'continue ad-free access.',
                  ),
                  _TermsSection(
                    n: 6,
                    title: 'Advertisements',
                    body:
                        'Free users will see banner ads, interstitial ads and '
                        'rewarded video ads served by Google AdMob, including '
                        'during live score viewing (after wickets and at the end '
                        'of overs). Subscribing removes all in-app ads.',
                  ),
                  _TermsSection(
                    n: 7,
                    title: 'Acceptable Use',
                    body:
                        'You agree NOT to:\n'
                        '  •  Impersonate another scorer or take over a match '
                        'without the original scorer\'s consent.\n'
                        '  •  Tamper with or falsify another user\'s match data.\n'
                        '  •  Reverse-engineer, decompile or modify the App.\n'
                        '  •  Share match passwords with unauthorised parties.\n'
                        '  •  Use the App for any unlawful purpose.',
                  ),
                  _TermsSection(
                    n: 8,
                    title: 'Scoring Accuracy',
                    body:
                        'You are solely responsible for the accuracy of all '
                        'scoring data you enter. ScoreBook provides the tools to '
                        'record and share scores but does not guarantee that any '
                        'match outcome, statistic or summary is dispute-free or '
                        'fit for official record-keeping.',
                  ),
                  _TermsSection(
                    n: 9,
                    title: 'Intellectual Property',
                    body:
                        'The ScoreBook name, logo, app design, source code and '
                        'all related materials are owned by ASKO Software '
                        'Solutions. You may not copy, redistribute, rebrand or '
                        'create derivative works of the App without written '
                        'permission.',
                  ),
                  _TermsSection(
                    n: 10,
                    title: 'Disclaimer & Limitation of Liability',
                    body:
                        'The App is provided "AS IS" and "AS AVAILABLE" without '
                        'warranties of any kind. To the maximum extent permitted '
                        'by law, ASKO Software Solutions shall not be liable for:\n'
                        '  •  Lost match data caused by device failure, '
                        'uninstallation or storage issues.\n'
                        '  •  Missed or delayed live score updates due to '
                        'network outages or third-party service downtime.\n'
                        '  •  Any indirect, incidental or consequential damages '
                        'arising from use of the App.',
                  ),
                  _TermsSection(
                    n: 11,
                    title: 'Termination',
                    body:
                        'We reserve the right to suspend or terminate access to '
                        'cloud features for any account that violates these '
                        'Terms. Local on-device scoring will continue to work.',
                  ),
                  _TermsSection(
                    n: 12,
                    title: 'Changes to These Terms',
                    body:
                        'We may update these Terms from time to time. The '
                        '"Effective date" at the top reflects the latest '
                        'revision. Continued use of the App after a change means '
                        'you accept the updated Terms.',
                  ),
                  _TermsSection(
                    n: 13,
                    title: 'Governing Law',
                    body:
                        'These Terms are governed by the laws of India. Any '
                        'disputes shall be subject to the exclusive jurisdiction '
                        'of courts in Tamil Nadu, India.',
                  ),
                  _TermsSection(
                    n: 14,
                    title: 'Contact',
                    body:
                        'Questions, complaints or feedback? Reach us at:\n'
                        '$_supportEmail',
                  ),

                  SizedBox(height: 16),
                  _TermsFooter(),
                ],
              ),
            ),
            // Footer button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Get.back(),
                    child: const Text('I Understand',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsMeta extends StatelessWidget {
  final String label;
  final String value;
  const _TermsMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        const Icon(Icons.event_rounded,
            size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800),
        ),
      ]),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final int n;
  final String title;
  final String body;
  const _TermsSection({
    required this.n,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              body,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsFooter extends StatelessWidget {
  const _TermsFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('🏏', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} ScoreBook · ASKO Software Solutions',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}