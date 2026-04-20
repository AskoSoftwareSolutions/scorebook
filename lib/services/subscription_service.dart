import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ad_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION SERVICE
//
// Firestore structure:
//   subscriptions/{phoneNumber} → {
//     phone:       '+919876543210',
//     name:        'Ravi Kumar',
//     email:       'ravi@example.com',   (optional)
//     plan:        '3month' | '1year',
//     startDate:   Timestamp,
//     expireDate:  Timestamp,
//     paymentId:   'pay_XXXX',
//     active:      true | false,
//   }
// ═══════════════════════════════════════════════════════════════════════════════

class SubscriptionService {
  static final SubscriptionService _i = SubscriptionService._();
  factory SubscriptionService() => _i;
  SubscriptionService._();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  SubscriptionInfo? _cached;

  // ── Plans ─────────────────────────────────────────────────────────────────
  static const plans = [
    SubscriptionPlan(
      id:          '3month',
      label:       '3 Months',
      price:       39,
      days:        90,
      description: 'Ad-free for 3 months',
      badge:       '',
    ),
    SubscriptionPlan(
      id:          '1year',
      label:       '1 Year',
      price:       100,
      days:        365,
      description: 'Best value — Ad-free for a full year',
      badge:       'BEST VALUE',
    ),
  ];

  // ── Current user phone ────────────────────────────────────────────────────
  String? get currentPhone => _auth.currentUser?.phoneNumber;
  bool    get isLoggedIn   => _auth.currentUser != null;

  // ── Load subscription for current user ───────────────────────────────────
  Future<SubscriptionInfo?> loadSubscription() async {
    if (!isLoggedIn) return null;
    final phone = currentPhone!;
    try {
      final doc = await _db.collection('subscriptions').doc(phone).get();
      if (!doc.exists) {
        _cached = null;
        AdService().setAdsEnabled(true);
        return null;
      }
      final data = doc.data()!;
      final info = SubscriptionInfo.fromMap(data);
      _cached = info;
      // Gate ads based on subscription
      AdService().setAdsEnabled(!info.isActive);
      return info;
    } catch (_) {
      return null;
    }
  }

  SubscriptionInfo? get cachedSubscription => _cached;

  // ── Save subscription after payment ──────────────────────────────────────
  Future<void> saveSubscription({
    required String phone,
    required String name,
    String? email,
    required String planId,
    required String paymentId,
  }) async {
    final plan = plans.firstWhere((p) => p.id == planId);
    final now  = DateTime.now();
    final exp  = now.add(Duration(days: plan.days));

    final info = SubscriptionInfo(
      phone:     phone,
      name:      name,
      email:     email,
      plan:      planId,
      startDate: now,
      expireDate: exp,
      paymentId: paymentId,
      active:    true,
    );

    await _db.collection('subscriptions').doc(phone).set(info.toMap());
    _cached = info;
    AdService().setAdsEnabled(false); // ads off immediately
  }

  // ── Update profile (name / email) ─────────────────────────────────────────
  Future<void> updateProfile({required String name, String? email}) async {
    if (!isLoggedIn) return;
    final phone = currentPhone!;
    await _db.collection('subscriptions').doc(phone).set(
      {'name': name, if (email != null) 'email': email},
      SetOptions(merge: true),
    );
    if (_cached != null) {
      _cached = _cached!.copyWith(name: name, email: email);
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class SubscriptionInfo {
  final String  phone;
  final String  name;
  final String? email;
  final String  plan;
  final DateTime startDate;
  final DateTime expireDate;
  final String  paymentId;
  final bool    active;

  const SubscriptionInfo({
    required this.phone,
    required this.name,
    this.email,
    required this.plan,
    required this.startDate,
    required this.expireDate,
    required this.paymentId,
    required this.active,
  });

  bool get isActive => active && expireDate.isAfter(DateTime.now());

  String get planLabel => plan == '1year' ? '1 Year' : '3 Months';

  String get expireFormatted {
    final d = expireDate;
    return '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/'
        '${d.year}';
  }

  String get daysLeft {
    final diff = expireDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Expired';
    if (diff == 1) return '1 day left';
    return '$diff days left';
  }

  factory SubscriptionInfo.fromMap(Map<String, dynamic> m) => SubscriptionInfo(
    phone:      m['phone']     ?? '',
    name:       m['name']      ?? '',
    email:      m['email'],
    plan:       m['plan']      ?? '3month',
    startDate:  (m['startDate']  as Timestamp).toDate(),
    expireDate: (m['expireDate'] as Timestamp).toDate(),
    paymentId:  m['paymentId']  ?? '',
    active:     m['active']     ?? false,
  );

  Map<String, dynamic> toMap() => {
    'phone':      phone,
    'name':       name,
    if (email != null) 'email': email,
    'plan':       plan,
    'startDate':  Timestamp.fromDate(startDate),
    'expireDate': Timestamp.fromDate(expireDate),
    'paymentId':  paymentId,
    'active':     active,
  };

  SubscriptionInfo copyWith({String? name, String? email}) => SubscriptionInfo(
    phone:      phone,
    name:       name ?? this.name,
    email:      email ?? this.email,
    plan:       plan,
    startDate:  startDate,
    expireDate: expireDate,
    paymentId:  paymentId,
    active:     active,
  );
}

class SubscriptionPlan {
  final String id;
  final String label;
  final int    price;
  final int    days;
  final String description;
  final String badge;
  const SubscriptionPlan({
    required this.id,
    required this.label,
    required this.price,
    required this.days,
    required this.description,
    required this.badge,
  });
}