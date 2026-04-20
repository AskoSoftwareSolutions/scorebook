import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../services/subscription_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION PAGE
// Shows plans → user selects → Razorpay payment → save to Firestore → ads off
//
// Replace 'YOUR_RAZORPAY_KEY_ID' with your actual key from Razorpay dashboard.
// ═══════════════════════════════════════════════════════════════════════════════

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _svc       = SubscriptionService();
  final _auth      = FirebaseAuth.instance;
  late  Razorpay   _razorpay;

  String?  _selectedPlan;
  bool     _loading = false;
  String?  _error;

  // Profile fields (shown before payment)
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool   _profileStep = false; // true = show profile form before payment

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);

    // Pre-fill name if we have cached profile
    final cached = _svc.cachedSubscription;
    if (cached != null) {
      _nameCtrl.text  = cached.name;
      _emailCtrl.text = cached.email ?? '';
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Payment success ───────────────────────────────────────────────────────
  void _onSuccess(PaymentSuccessResponse r) async {
    setState(() => _loading = true);
    final phone = _auth.currentUser?.phoneNumber ?? '';
    try {
      await _svc.saveSubscription(
        phone:     phone,
        name:      _nameCtrl.text.trim(),
        email:     _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        planId:    _selectedPlan!,
        paymentId: r.paymentId ?? '',
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = 'Payment recorded but profile save failed. Contact support.';
      });
    }
  }

  void _onError(PaymentFailureResponse r) {
    setState(() => _error = 'Payment failed: ${r.message}');
    HapticFeedback.heavyImpact();
  }

  void _onWallet(ExternalWalletResponse r) {
    // External wallet — nothing to do
  }

  // ── Open payment ──────────────────────────────────────────────────────────
  void _openPayment() {
    if (_selectedPlan == null) {
      setState(() => _error = 'Please select a plan');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    final plan = SubscriptionService.plans
        .firstWhere((p) => p.id == _selectedPlan!);

    final options = {
      'key':         'rzp_test_SQSCxz08moLxIn', // ← replace with real key
      'amount':      plan.price * 100,       // amount in paise
      'name':        'Cricket Scorer',
      'description': '${plan.label} — Ad-free subscription',
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber ?? '',
        'email':   _emailCtrl.text.trim().isEmpty
            ? 'user@cricket.app'
            : _emailCtrl.text.trim(),
      },
      'theme': {'color': '#43A047'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _error = 'Could not open payment. Try again.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primaryLight, size: 44),
              ),
              const SizedBox(height: 16),
              const Text('Payment Successful!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              const Text(
                'You are now Ad-free 🎉\nEnjoy uninterrupted cricket scoring!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.6),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Get.back(); // close dialog
                    Get.back(); // back to settings
                  },
                  child: const Text('Great, Thanks!',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = _svc.cachedSubscription;

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
          title: const Text('Go Ad-Free',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Active sub banner ─────────────────────────────────────
                if (existing != null && existing.isActive)
                  _ActiveSubBanner(info: existing),

                // ── Hero ─────────────────────────────────────────────────
                if (existing == null || !existing.isActive)
                  _HeroBanner(),

                const SizedBox(height: 24),

                // ── Plan cards ────────────────────────────────────────────
                if (existing == null || !existing.isActive) ...[
                  const Text('Choose a Plan',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 12),
                  ...SubscriptionService.plans.map((plan) => _PlanCard(
                    plan: plan,
                    selected: _selectedPlan == plan.id,
                    onTap: () =>
                        setState(() { _selectedPlan = plan.id; _error = null; }),
                  )),

                  const SizedBox(height: 20),

                  // ── Profile form ──────────────────────────────────────
                  const Text('Your Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 12),
                  _FormField(
                    label: 'NAME *',
                    controller: _nameCtrl,
                    hint: 'Your full name',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    label: 'EMAIL (optional)',
                    controller: _emailCtrl,
                    hint: 'your@email.com',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  // ── Error ─────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.error.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Pay button ────────────────────────────────────────
                  _PayButton(
                    selectedPlan: _selectedPlan == null
                        ? null
                        : SubscriptionService.plans
                        .firstWhere((p) => p.id == _selectedPlan!),
                    loading: _loading,
                    onTap: _openPayment,
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '100% secure payment via Razorpay\nUPI · Cards · Net Banking · Wallets',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Active subscription banner ────────────────────────────────────────────────
class _ActiveSubBanner extends StatelessWidget {
  final SubscriptionInfo info;
  const _ActiveSubBanner({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Ad-Free Active',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(info.planLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          Text('Expires: ${info.expireFormatted}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(info.daysLeft,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Text('🚫', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text('Remove All Ads',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text(
            'No banner ads · No video interruptions\nScore freely, distraction-free',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.8),
                fontSize: 12,
                height: 1.6),
          ),
          const SizedBox(height: 14),
          _FeatureRow(icon: Icons.block_rounded,       text: 'No ads after wickets'),
          _FeatureRow(icon: Icons.block_rounded,       text: 'No ads after every over'),
          _FeatureRow(icon: Icons.picture_as_pdf_rounded, text: 'No ads on PDF export'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, color: AppTheme.primaryLight, size: 14),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
    ]),
  );
}

// ── Plan card ─────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard(
      {required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryLight.withOpacity(0.08)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.primaryLight
                : AppTheme.borderColor,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(children: [
          // Radio
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected
                      ? AppTheme.primaryLight
                      : AppTheme.textSecondary,
                  width: selected ? 0 : 1.5),
              color: selected ? AppTheme.primaryLight : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(plan.label,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      )),
                  if (plan.badge.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.4)),
                      ),
                      child: Text(plan.badge,
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(plan.description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          // Price
          Text('₹${plan.price}',
              style: TextStyle(
                color: selected
                    ? AppTheme.primaryLight
                    : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              )),
        ]),
      ),
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
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
              letterSpacing: 1.2)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
          prefixIcon: Icon(icon,
              color: AppTheme.textSecondary, size: 18),
          filled: true,
          fillColor: AppTheme.bgCard,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppTheme.primaryLight, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

// ── Pay button ────────────────────────────────────────────────────────────────
class _PayButton extends StatelessWidget {
  final SubscriptionPlan? selectedPlan;
  final bool loading;
  final VoidCallback onTap;
  const _PayButton(
      {required this.selectedPlan,
        required this.loading,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = selectedPlan == null
        ? 'Select a plan'
        : 'Pay ₹${selectedPlan!.price} — Go Ad-Free';

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: (loading || selectedPlan == null)
              ? LinearGradient(colors: [
            AppTheme.primary.withOpacity(0.4),
            AppTheme.primaryLight.withOpacity(0.4),
          ])
              : const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: (loading || selectedPlan == null)
              ? []
              : [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: (loading || selectedPlan == null) ? null : onTap,
          child: loading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}