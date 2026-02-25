import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'donate_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _selectedCategory = 0;
  Map<String, dynamic>? _user;
  List<dynamic> _myDonations = [];
  List<dynamic> _allDonations = [];

  final List<String> _categories = [
    'ALL CUISINES',
    'PIZZA',
    'FAST FOOD',
    'GREEK',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDonations();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

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
          _allDonations = all;
          _myDonations = my;
        });
      }
    } catch (_) {}
  }

  void _openDonateForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DonateFormScreen()),
    );
    if (result == true) {
      _loadDonations(); // refresh after successful donation
    }
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
          // ── Top row: avatar + greeting + cart ──────────────────
          Row(
            children: [
              // Profile avatar
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
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Let's order a food,",
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
              // Orange cart button
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Search bar ─────────────────────────────────────────
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.chevron_left, color: Colors.grey[400], size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Find for food or resto ...',
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
                Icon(Icons.search, color: Colors.grey[400], size: 22),
                const SizedBox(width: 8),
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
          const SizedBox(height: 20),
          // ── Category text tabs ────────────────────────────────
          Row(
            children: [
              _textTab('Breakfast', true, '24'),
              const SizedBox(width: 24),
              _textTab('Dinner', false, null),
              const SizedBox(width: 24),
              _textTab('Have Lunch', false, null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textTab(String label, bool isActive, String? badge) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
            fontSize: 15,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Page bodies ──────────────────────────────────────────────────────
  Widget _buildExplore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFFF7F7F7),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ── "Today options" + category chips ─────────────
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Today options',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildCategoryChips(),
                const SizedBox(height: 20),

                // ── Promo card ───────────────────────────────────
                _buildPromoCard(),
                const SizedBox(height: 20),

                // ── Food list items ──────────────────────────────
                _buildFoodListItem(
                  imgUrl:
                      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=200&auto=format&fit=crop&q=60',
                  name: 'Bread with Chicken',
                  kcal: '450 kkal per portion',
                  ingredients: ['🧇', '🍗', '🥙'],
                  price: '\$9.99',
                  isHighlighted: false,
                ),
                _buildFoodListItem(
                  imgUrl:
                      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200&auto=format&fit=crop&q=60',
                  name: 'Greek Salad with Sauce',
                  kcal: '450 kkal per portion',
                  ingredients: ['🍅', '🥤', '🥦'],
                  price: '\$7.55',
                  isHighlighted: true,
                ),
                _buildFoodListItem(
                  imgUrl:
                      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&auto=format&fit=crop&q=60',
                  name: 'Pizza Margharita',
                  kcal: '150 kkal per portion',
                  ingredients: ['🍕', '🍅'],
                  price: '\$8.99',
                  isHighlighted: false,
                ),
                _buildFoodListItem(
                  imgUrl:
                      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=200&auto=format&fit=crop&q=60',
                  name: 'Citrus Salad Bowl',
                  kcal: '210 kkal per portion',
                  ingredients: ['🥗', '🍋', '🫐'],
                  price: '\$6.49',
                  isHighlighted: false,
                ),

                // ── All Donated Foods ────────────────────────────
                if (_allDonations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Donated Foods',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._allDonations.map((d) => _buildDonationCard(d)),
                ],

                // ── My Donations ─────────────────────────────────
                if (_myDonations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'My Donations',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._myDonations.map((d) => _buildDonationCard(d)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Category pills ───────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_categories.length, (i) {
          final isActive = _selectedCategory == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF4CAF50) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF4CAF50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _categories[i],
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Promo card ────────────────────────────────────────────────────────
  Widget _buildPromoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 150,
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
                    'The best lunch\nof the day',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start from \$3',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _deliveryChip(
                        Icons.local_shipping_outlined,
                        'free delivery',
                      ),
                      const SizedBox(width: 8),
                      _deliveryChip(Icons.access_time_outlined, '15-20 mins'),
                    ],
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
            child: Image.network(
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=300&auto=format&fit=crop&q=80',
              width: 140,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140,
                color: const Color(0xFF388E3C),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Food list item ────────────────────────────────────────────────────
  Widget _buildFoodListItem({
    required String imgUrl,
    required String name,
    required String kcal,
    required List<String> ingredients,
    required String price,
    required bool isHighlighted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF4CAF50) : Colors.white,
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
            child: Image.network(
              imgUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: Colors.grey[200],
                child: Icon(Icons.fastfood, color: Colors.grey[400], size: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kcal,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isHighlighted
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                // Ingredient bubbles + price
                Row(
                  children: [
                    ...ingredients.map(
                      (e) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Price
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '\$',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isHighlighted
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: price.replaceFirst('\$', ''),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isHighlighted
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Heart
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border,
              size: 16,
              color: isHighlighted ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ── Donation card (for explore / my donations sections) ───────────
  Widget _buildDonationCard(dynamic donation) {
    final d = donation as Map<String, dynamic>;
    final title = d['title'] ?? 'Untitled';
    final desc = d['description'] ?? '';
    final category = d['category'] ?? 'edible';
    final foodType = d['food_type'] ?? '';
    final imageUrl = d['image_url'];
    final donorName = d['donor_name'] ?? 'Anonymous';

    Color categoryColor;
    IconData categoryIcon;
    switch (category) {
      case 'edible':
        categoryColor = AppColors.primary;
        categoryIcon = Icons.check_circle;
        break;
      case 'recyclable':
        categoryColor = Colors.orange;
        categoryIcon = Icons.recycling;
        break;
      default:
        categoryColor = AppColors.error;
        categoryIcon = Icons.cancel;
    }

    return Container(
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
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.fastfood,
                        color: Colors.grey[400],
                        size: 30,
                      ),
                    ),
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.fastfood,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
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
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon, size: 12, color: categoryColor),
                          const SizedBox(width: 4),
                          Text(
                            category.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Food type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        foodType.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      donorName,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCart() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDonate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ─── Hero section (matching design) ───────────────────
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

          // ─── Impact stats ─────────────────────────────────────
          Row(
            children: [
              _statCard('126', 'Meals\nShared', Icons.volunteer_activism),
              const SizedBox(width: 12),
              _statCard('48', 'Active\nDonors', Icons.people_outline),
              const SizedBox(width: 12),
              _statCard('35 kg', 'Waste\nSaved', Icons.delete_outline),
            ],
          ),
        ],
      ),
    );
  }

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
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
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

  Widget _buildMenu() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Text(
          'DEMETRA',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Zero Waste Food Management',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        _menuItem(Icons.info_outline, 'About Us'),
        _menuItem(Icons.help_outline, 'Help & Support'),
        _menuItem(Icons.policy_outlined, 'Privacy Policy'),
        _menuItem(Icons.description_outlined, 'Terms of Service'),
        _menuItem(Icons.star_outline, 'Rate the App'),
        _menuItem(Icons.share_outlined, 'Share with Friends'),
        const SizedBox(height: 28),
        Center(
          child: Text(
            'v1.0.0',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
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
  }

  Widget _profileTile(IconData icon, String label, String value) {
    return Padding(
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
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
  }

  Widget _menuItem(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () {},
      ),
    );
  }

  // ─── Pages list ───────────────────────────────────────────────────────
  Widget get _body {
    switch (_currentIndex) {
      case 0:
        return _buildExplore();
      case 1:
        return _buildCart();
      case 2:
        return _buildDonate();
      case 3:
        return _buildProfile();
      case 4:
        return _buildMenu();
      default:
        return _buildDonate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _body,
      bottomNavigationBar: Container(
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
                _navItem(1, Icons.shopping_cart_outlined, 'Cart'),
                _donateFab(),
                _navItem(3, Icons.person_outline, 'Profile'),
                _navItem(4, Icons.menu, 'Menu'),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _donateFab() {
    final isActive = _currentIndex == 2;
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
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
