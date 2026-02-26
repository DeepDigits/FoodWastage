import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'donate_form_screen.dart';
import 'food_detail_screen.dart';
import 'cart_screen.dart';
import 'requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Navigation ───────────────────────────────────────────────────────
  int _currentIndex = 0;

  // ── Data ─────────────────────────────────────────────────────────────
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _allDonations = [];
  List<Map<String, dynamic>> _myDonations = [];
  int _cartCount = 0;

  // ── Today Options filter ─────────────────────────────────────────────
  int _todayFilter = 0; // 0=All, 1=Organic, 2=Packed, 3=Homely
  final _todayLabels = ['All', 'Organic', 'Packed', 'Homely'];
  final _todayTypes = ['', 'organic', 'packed', 'homecooked'];

  // ── Organic section filter ───────────────────────────────────────────
  int _organicSoldFilter = 0; // 0=All, 1=Available, 2=Sold
  final _organicSoldLabels = ['All', 'Available', 'Sold'];

  // ── Expiry countdown ─────────────────────────────────────────────────
  Timer? _expiryTimer;
  Duration _expiryRemaining = Duration.zero;
  Map<String, dynamic>? _expiringItem;

  // ====================================================================
  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDonations();
    _refreshCartCount();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────
  Future<void> _loadUser() async {
    final u = await ApiService.getUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _loadDonations() async {
    try {
      final all = await ApiService.getDonations();
      final my = await ApiService.getMyDonations();
      if (mounted) {
        setState(() {
          _allDonations = all.cast<Map<String, dynamic>>();
          _myDonations = my.cast<Map<String, dynamic>>();
        });
        _findExpiringItem();
      }
    } catch (_) {}
  }

  Future<void> _refreshCartCount() async {
    final c = await CartService.count();
    if (mounted) setState(() => _cartCount = c);
  }

  // ── Helpers: filter lists ────────────────────────────────────────────
  int? get _currentUserId => _user?['id'];

  /// Donations by OTHER users only.
  List<Map<String, dynamic>> get _othersDonations {
    if (_currentUserId == null) return _allDonations;
    return _allDonations.where((d) => d['donor'] != _currentUserId).toList();
  }

  /// "Today options" – filtered by food type toggle.
  List<Map<String, dynamic>> get _todayDonations {
    final base = _othersDonations;
    if (_todayFilter == 0) return base;
    final type = _todayTypes[_todayFilter];
    return base.where((d) => d['food_type'] == type).toList();
  }

  /// Organic items from other users, with sold filter.
  List<Map<String, dynamic>> get _organicDonations {
    var list = _othersDonations
        .where((d) => d['food_type'] == 'organic')
        .toList();
    if (_organicSoldFilter == 1) {
      list = list.where((d) => d['is_sold'] != true).toList();
    } else if (_organicSoldFilter == 2) {
      list = list.where((d) => d['is_sold'] == true).toList();
    }
    return list;
  }

  // ── Best launch: packed item closest to expiry ───────────────────────
  void _findExpiringItem() {
    _expiryTimer?.cancel();
    final now = DateTime.now();
    Map<String, dynamic>? best;
    Duration? bestDiff;

    for (final d in _othersDonations) {
      if (d['food_type'] != 'packed') continue;
      if (d['is_sold'] == true) continue;
      final exp = d['expiry_date'];
      if (exp == null) continue;
      try {
        final expDate = DateTime.parse(exp);
        final expEnd = DateTime(
          expDate.year,
          expDate.month,
          expDate.day,
          23,
          59,
          59,
        );
        final diff = expEnd.difference(now);
        if (diff.isNegative) continue; // already expired
        if (best == null || diff < bestDiff!) {
          best = d;
          bestDiff = diff;
        }
      } catch (_) {}
    }

    if (best != null && bestDiff != null) {
      setState(() {
        _expiringItem = best;
        _expiryRemaining = bestDiff!;
      });
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final rem = _expiryRemaining - const Duration(seconds: 1);
        if (rem.isNegative) {
          _expiryTimer?.cancel();
          setState(() => _expiringItem = null);
        } else {
          setState(() => _expiryRemaining = rem);
        }
      });
    } else {
      setState(() => _expiringItem = null);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  // ── Navigation helpers ───────────────────────────────────────────────
  void _openDonateForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DonateFormScreen()),
    );
    if (result == true) _loadDonations();
  }

  void _openDetail(Map<String, dynamic> d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodDetailScreen(donation: d)),
    );
    _refreshCartCount();
  }

  void _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    _refreshCartCount();
  }

  // ====================================================================
  // ██  BUILD
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _body,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget get _body {
    switch (_currentIndex) {
      case 0:
        return _buildExplore();
      case 1:
        return CartScreen(key: ValueKey(_cartCount));
      case 2:
        return _buildDonate();
      case 3:
        return const RequestsScreen();
      case 4:
        return _buildProfile();
      default:
        return _buildExplore();
    }
  }

  // ====================================================================
  // ██  EXPLORE (Home)
  // ====================================================================
  Widget _buildExplore() {
    return Column(
      children: [
        _buildHomeHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDonations();
              await _refreshCartCount();
            },
            child: Container(
              color: const Color(0xFFF7F7F7),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // ── Today Options ────────────────────────────
                  const SizedBox(height: 22),
                  _sectionTitle('Today options'),
                  const SizedBox(height: 14),
                  _buildTodayToggle(),
                  const SizedBox(height: 16),
                  ..._todayDonations.map(_buildDonationCard),
                  if (_todayDonations.isEmpty)
                    _emptyHint('No donations in this category yet'),

                  // ── Best Launch of the Day ───────────────────
                  if (_expiringItem != null) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('Best launch of the day'),
                    const SizedBox(height: 14),
                    _buildExpiryCard(),
                  ],

                  // ── Organic Donated Items ────────────────────
                  const SizedBox(height: 24),
                  _sectionTitle('Organic Donated Items'),
                  const SizedBox(height: 10),
                  _buildOrganicToggle(),
                  const SizedBox(height: 12),
                  ..._organicDonations.map(_buildDonationCard),
                  if (_organicDonations.isEmpty)
                    _emptyHint('No organic donations yet'),

                  // ── My Donations ─────────────────────────────
                  if (_myDonations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('My Donations'),
                    const SizedBox(height: 12),
                    ..._myDonations.map(_buildDonationCard),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────
  Widget _buildHomeHeader() {
    final name = _user?['full_name']?.toString().split(' ').first ?? 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 16,
        24,
        28,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Let's save some food,",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Cart button with badge
              GestureDetector(
                onTap: _openCart,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF57C00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    if (_cartCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: Colors.grey[400], size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search donated food...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section title ───────────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _emptyHint(String msg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Center(
      child: Text(
        msg,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );

  // ─── Today Options toggle ────────────────────────────────────────────
  Widget _buildTodayToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_todayLabels.length, (i) {
          final active = _todayFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _todayFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF4CAF50) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: active
                      ? const Color(0xFF4CAF50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _todayLabels[i],
                style: GoogleFonts.poppins(
                  color: active ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Organic sold/available toggle ───────────────────────────────────
  Widget _buildOrganicToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_organicSoldLabels.length, (i) {
          final active = _organicSoldFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _organicSoldFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: active ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _organicSoldLabels[i],
                style: GoogleFonts.poppins(
                  color: active ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Donation card (reusable) ────────────────────────────────────────
  Widget _buildDonationCard(Map<String, dynamic> d) {
    final title = d['title'] ?? 'Untitled';
    final desc = d['description'] ?? '';
    final category = d['category'] ?? 'edible';
    final foodType = d['food_type'] ?? '';
    final imageUrl = d['image_url'];
    final donorName = d['donor_name'] ?? 'Anonymous';
    final isSold = d['is_sold'] == true;

    Color catColor;
    IconData catIcon;
    switch (category) {
      case 'edible':
        catColor = AppColors.primary;
        catIcon = Icons.check_circle;
        break;
      case 'recyclable':
        catColor = Colors.orange;
        catIcon = Icons.recycling;
        break;
      default:
        catColor = AppColors.error;
        catIcon = Icons.cancel;
    }

    return GestureDetector(
      onTap: () => _openDetail(d),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _smallBadge(catIcon, category.toUpperCase(), catColor),
                      const SizedBox(width: 6),
                      _typeBadge(foodType.toUpperCase()),
                      const Spacer(),
                      if (isSold)
                        _statusLabel('SOLD', AppColors.error)
                      else
                        _statusLabel('AVAILABLE', AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $donorName',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Expiry countdown card ───────────────────────────────────────────
  Widget _buildExpiryCard() {
    final d = _expiringItem!;
    final title = d['title'] ?? 'Packed Food';
    final imageUrl = d['image_url'];
    final donorName = d['donor_name'] ?? 'Anonymous';
    final expiry = d['expiry_date'] ?? '';

    return GestureDetector(
      onTap: () => _openDetail(d),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by $donorName',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expiry: $expiry',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(_expiryRemaining),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 140,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        color: const Color(0xFF388E3C),
                        child: const Icon(
                          Icons.fastfood,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    )
                  : Container(
                      width: 140,
                      color: const Color(0xFF388E3C),
                      child: const Icon(
                        Icons.fastfood,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Badge helpers ───────────────────────────────────────────────────
  Widget _imgPlaceholder() => Container(
    width: 72,
    height: 72,
    color: Colors.grey[200],
    child: Icon(Icons.fastfood, color: Colors.grey[400], size: 30),
  );

  Widget _smallBadge(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _typeBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      ),
    ),
  );

  Widget _statusLabel(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  // ====================================================================
  // ██  DONATE TAB
  // ====================================================================
  Widget _buildDonate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withOpacity(0.06),
                  AppColors.background,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Zero Waste Initiative',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    children: [
                      const TextSpan(text: 'Share Food,\n'),
                      TextSpan(
                        text: 'Save Earth.',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect with your community to share surplus food. '
                  "Whether it's edible, upcyclable, or compostable—nothing should go to waste.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentIndex = 0),
                    child: const Text('Find Food'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: OutlinedButton(
                    onPressed: _openDonateForm,
                    child: const Text('Start Donating'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _statCard(
                '${_allDonations.length}',
                'Meals\nShared',
                Icons.volunteer_activism,
              ),
              const SizedBox(width: 12),
              _statCard(
                '${_myDonations.length}',
                'My\nDonations',
                Icons.card_giftcard,
              ),
              const SizedBox(width: 12),
              _statCard(
                '${_othersDonations.where((d) => d['is_sold'] != true).length}',
                'Available\nNow',
                Icons.local_offer_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // ██  PROFILE TAB
  // ====================================================================
  Widget _buildProfile() {
    final name = _user?['full_name'] ?? 'User';
    final email = _user?['email'] ?? '';
    final userType = _user?['user_type'] ?? 'citizen';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userType[0].toUpperCase() + userType.substring(1),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _profileTile(Icons.phone_outlined, 'Phone', _user?['phone'] ?? '—'),
        _profileTile(
          Icons.location_city_outlined,
          'District',
          _user?['district'] ?? '—',
        ),
        _profileTile(
          Icons.pin_drop_outlined,
          'Pin Code',
          _user?['pin_code'] ?? '—',
        ),
        _profileTile(
          Icons.home_outlined,
          'Address',
          _user?['full_address'] ?? '—',
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () async {
            await ApiService.logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: Icon(Icons.logout, color: AppColors.error),
          label: Text('Logout', style: TextStyle(color: AppColors.error)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.error),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // ██  COMMON WIDGETS
  // ====================================================================
  Widget _statCard(String value, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _profileTile(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ─── Bottom Navigation Bar ───────────────────────────────────────────
  Widget _buildBottomBar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.search, 'Explore'),
            _navItemWithBadge(
              1,
              Icons.shopping_cart_outlined,
              'Cart',
              _cartCount,
            ),
            _donateFab(),
            _navItem(3, Icons.mail_outline, 'Requests'),
            _navItem(4, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItemWithBadge(int index, IconData icon, String label, int count) {
    final isActive = _currentIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _donateFab() {
    return GestureDetector(
      onTap: _openDonateForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 3),
          Text(
            'Donate',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
