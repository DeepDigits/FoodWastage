import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/cart_service.dart';
import '../services/api_service.dart';

/// Full-screen detail page for a food donation.
/// Shows image, title, description, badges, donor info, Gemini analysis.
/// "Add to Cart" button – disabled if this is the current user's own donation.
class FoodDetailScreen extends StatefulWidget {
  final Map<String, dynamic> donation;
  const FoodDetailScreen({super.key, required this.donation});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  bool _inCart = false;
  bool _isOwn = false;
  bool _loading = true;
  bool _requestSent = false;
  String _requestStatus = ''; // pending, accepted, rejected

  Map<String, dynamic> get d => widget.donation;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = await ApiService.getUser();
    final userId = user?['id'];
    final donorId = d['donor'];
    final inCart = await CartService.isInCart(d['id']);

    // Check if buy request already exists
    bool requestSent = false;
    String requestStatus = '';
    try {
      final reqCheck = await ApiService.checkBuyRequest(d['id']);
      if (reqCheck['has_request'] == true) {
        requestSent = true;
        requestStatus = reqCheck['status'] ?? 'pending';
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isOwn = userId != null && donorId != null && userId == donorId;
        _inCart = inCart;
        _requestSent = requestSent;
        _requestStatus = requestStatus;
        _loading = false;
      });
    }
  }

  Future<void> _addToCart() async {
    await CartService.addItem(d);
    if (mounted) {
      setState(() => _inCart = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${d['title']} added to cart'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeFromCart() async {
    await CartService.removeItem(d['id']);
    if (mounted) {
      setState(() => _inCart = false);
    }
  }

  Future<void> _sendBuyRequest() async {
    try {
      final res = await ApiService.sendBuyRequest(donationId: d['id']);
      if (res['statusCode'] == 201) {
        if (mounted) {
          setState(() {
            _requestSent = true;
            _requestStatus = 'pending';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Buy request sent successfully!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to send request'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Network error. Try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = d['title'] ?? 'Untitled';
    final desc = d['description'] ?? '';
    final category = d['category'] ?? 'edible';
    final foodType = d['food_type'] ?? '';
    final imageUrl = d['image_url'];
    final donorName = d['donor_name'] ?? 'Anonymous';
    final address = d['address'] ?? '';
    final isSold = d['is_sold'] == true;
    final expiryDate = d['expiry_date'];
    final safetyHours = d['safety_hours'];
    final gemini = d['gemini_analysis'] as Map<String, dynamic>? ?? {};

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Image app bar ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black26,
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryLight,
                        child: const Icon(
                          Icons.fastfood,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.primaryLight,
                      child: const Icon(
                        Icons.fastfood,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + sold badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSold)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SOLD',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'AVAILABLE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Badges row
                  Row(
                    children: [
                      _badge(catIcon, category.toUpperCase(), catColor),
                      const SizedBox(width: 8),
                      _badge(
                        Icons.restaurant,
                        foodType.toUpperCase(),
                        Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info cards
                  _infoRow(Icons.person_outline, 'Donated by', donorName),
                  if (address.isNotEmpty)
                    _infoRow(Icons.location_on_outlined, 'Location', address),
                  if (expiryDate != null)
                    _infoRow(Icons.calendar_today, 'Expiry Date', expiryDate),
                  if (safetyHours != null)
                    _infoRow(
                      Icons.timer_outlined,
                      'Safe for',
                      '$safetyHours hours',
                    ),

                  // Gemini analysis
                  if (gemini.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'AI Analysis',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (gemini['detected_items'] is List)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (gemini['detected_items'] as List)
                            .map(
                              (e) => Chip(
                                label: Text(
                                  e.toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.08,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (gemini['freshness'] != null) ...[
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.eco_outlined,
                        'Freshness',
                        gemini['freshness'],
                      ),
                    ],
                    if (gemini['reason'] != null) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.info_outline, 'Reason', gemini['reason']),
                    ],
                  ],
                  const SizedBox(height: 100), // space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom button ──
      bottomNavigationBar: _loading
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              child: _isOwn
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'This is your donation',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : isSold
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'This item has been sold',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Cart button
                        Expanded(
                          child: _inCart
                              ? SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _removeFromCart,
                                    icon: const Icon(
                                      Icons.remove_shopping_cart,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Remove',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: BorderSide(color: AppColors.error),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _addToCart,
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Add to Cart',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        // Buy request button
                        Expanded(
                          child: _requestSent
                              ? SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: Icon(
                                      _requestStatus == 'accepted'
                                          ? Icons.check_circle
                                          : _requestStatus == 'rejected'
                                          ? Icons.cancel
                                          : Icons.hourglass_top,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _requestStatus == 'accepted'
                                          ? 'Accepted'
                                          : _requestStatus == 'rejected'
                                          ? 'Rejected'
                                          : 'Requested',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          _requestStatus == 'accepted'
                                          ? AppColors.primary
                                          : _requestStatus == 'rejected'
                                          ? AppColors.error
                                          : Colors.orange,
                                      side: BorderSide(
                                        color: _requestStatus == 'accepted'
                                            ? AppColors.primary
                                            : _requestStatus == 'rejected'
                                            ? AppColors.error
                                            : Colors.orange,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _sendBuyRequest,
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Buy Request',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF57C00),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
