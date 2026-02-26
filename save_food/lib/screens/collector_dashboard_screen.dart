import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'route_map_screen.dart';

class CollectorDashboardScreen extends StatefulWidget {
  const CollectorDashboardScreen({super.key});

  @override
  State<CollectorDashboardScreen> createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _collector;
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;

  // Filter: 0 = All, 1 = Waiting, 2 = Collected, 3 = Delivered
  int _filter = 0;
  final _filterLabels = ['All', 'Waiting', 'Collected', 'Delivered'];
  final _filterValues = ['', 'waiting', 'collected', 'delivered'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await ApiService.getUser();
      final collector = await ApiService.getCollector();
      final assignments = await ApiService.getCollectorDashboard();
      if (mounted) {
        setState(() {
          _user = user;
          _collector = collector;
          _assignments = assignments.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_filter == 0) return _assignments;
    final val = _filterValues[_filter];
    return _assignments.where((a) => a['delivery_status'] == val).toList();
  }

  Future<void> _verifyOTP(int requestId, String otp) async {
    try {
      final res = await ApiService.verifyCollectorOTP(
        requestId: requestId,
        otp: otp,
      );
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'OTP verified!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Invalid OTP'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showOTPDialog(int requestId, String deliveryStatus) {
    final otpCtrl = TextEditingController();
    final expected = deliveryStatus == 'waiting' ? 'Sender' : 'Receiver';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.deepOrange, size: 24),
            const SizedBox(width: 10),
            Text(
              'Enter $expected OTP',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              deliveryStatus == 'waiting'
                  ? 'Enter the OTP from the food donor to mark as collected.'
                  : 'Enter the OTP from the requester to mark as delivered.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 24,
                  letterSpacing: 8,
                  color: Colors.grey.shade300,
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Colors.deepOrange,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final otp = otpCtrl.text.trim();
              if (otp.isNotEmpty) {
                Navigator.pop(ctx);
                _verifyOTP(requestId, otp);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Verify',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ====================================================================
  @override
  Widget build(BuildContext context) {
    final greeting = _user != null
        ? 'Hi, ${_user!['full_name']?.toString().split(' ').first ?? 'Collector'}!'
        : 'Hi, Collector!';
    final zone = _collector?['zone'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── Green header ──────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(greeting, zone)),

            // ── Filter chips ──────────────────────────────────────────
            SliverToBoxAdapter(child: _buildFilterChips()),

            // ── Stats row ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildStats()),

            // ── Assignment cards ──────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredAssignments.isEmpty)
              SliverFillRemaining(child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _assignmentCard(_filteredAssignments[i]),
                    childCount: _filteredAssignments.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader(String greeting, String zone) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Food Waste Collector',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    if (zone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Zone: $zone',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Logout button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filterLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = _filter == i;
            return GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: selected ? Colors.deepOrange : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? Colors.deepOrange : Colors.grey.shade300,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.deepOrange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  _filterLabels[i],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────
  Widget _buildStats() {
    final waiting = _assignments
        .where((a) => a['delivery_status'] == 'waiting')
        .length;
    final collected = _assignments
        .where((a) => a['delivery_status'] == 'collected')
        .length;
    final delivered = _assignments
        .where((a) => a['delivery_status'] == 'delivered')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _statCard('Waiting', waiting, Colors.orange),
          const SizedBox(width: 10),
          _statCard('Collected', collected, Colors.blue),
          const SizedBox(width: 10),
          _statCard('Delivered', delivered, AppColors.primary),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Assignment card ────────────────────────────────────────────────
  Widget _assignmentCard(Map<String, dynamic> req) {
    final reqId = req['id'] as int;
    final donTitle = req['donation_title'] ?? 'Untitled';
    final donImage = req['donation_image_url'];
    final donorName = req['donor_name'] ?? 'Unknown';
    final requesterName = req['requester_name'] ?? 'Unknown';
    final requesterPhone = req['requester_phone'] ?? '';
    final requesterAddress = req['requester_address'] ?? '';
    final deliveryStatus = req['delivery_status'] ?? 'waiting';

    // Donation data for address
    final donationData = req['donation_data'] as Map<String, dynamic>?;
    final donAddress = donationData?['address'] ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (deliveryStatus) {
      case 'collected':
        statusColor = Colors.blue;
        statusIcon = Icons.inventory_2_rounded;
        statusLabel = 'Collected';
        break;
      case 'delivered':
        statusColor = AppColors.primary;
        statusIcon = Icons.check_circle;
        statusLabel = 'Delivered';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusLabel = 'Waiting';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Food header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: donImage != null
                      ? Image.network(
                          donImage,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(req['created_at'] ?? ''),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Pickup & Delivery Info ──────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Donor (Pickup from)
                _infoSection(
                  'Pickup From (Donor)',
                  Icons.store_rounded,
                  Colors.deepOrange,
                  [
                    _detailRow(Icons.person_outline, donorName),
                    if (donAddress.isNotEmpty)
                      _detailRow(Icons.location_on_outlined, donAddress),
                  ],
                ),
                const SizedBox(height: 12),
                // Requester (Deliver to)
                _infoSection(
                  'Deliver To (Requester)',
                  Icons.person_pin_circle_rounded,
                  Colors.blue,
                  [
                    _detailRow(Icons.person_outline, requesterName),
                    if (requesterPhone.isNotEmpty)
                      _detailRow(Icons.phone_outlined, requesterPhone),
                    if (requesterAddress.isNotEmpty)
                      _detailRow(Icons.home_outlined, requesterAddress),
                  ],
                ),
              ],
            ),
          ),

          // ── Delivery progress indicator ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _deliveryProgress(deliveryStatus),
          ),

          // ── Map Route Button ──────────────────────────
          if (donationData?['latitude'] != null &&
              donationData?['longitude'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final lat = (donationData!['latitude'] as num).toDouble();
                    final lng = (donationData['longitude'] as num).toDouble();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteMapScreen(
                          destLat: lat,
                          destLng: lng,
                          destLabel: 'Pickup: $donTitle',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(
                    'View Route to Pickup',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // ── OTP Verify Button ──────────────────────────
          if (deliveryStatus != 'delivered')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _showOTPDialog(reqId, deliveryStatus),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: Text(
                    deliveryStatus == 'waiting'
                        ? 'Enter Sender OTP (Collect)'
                        : 'Enter Receiver OTP (Deliver)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deliveryStatus == 'waiting'
                        ? Colors.deepOrange
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

          if (deliveryStatus == 'delivered')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Successfully Delivered!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Info section ─────────────────────────────────────────────────
  Widget _infoSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ── Delivery progress ──────────────────────────────────────────
  Widget _deliveryProgress(String status) {
    final step = status == 'waiting'
        ? 0
        : status == 'collected'
        ? 1
        : 2;

    return Row(
      children: [
        _progressDot(0, step, 'Waiting', Colors.orange),
        Expanded(child: _progressLine(step >= 1)),
        _progressDot(1, step, 'Collected', Colors.blue),
        Expanded(child: _progressLine(step >= 2)),
        _progressDot(2, step, 'Delivered', AppColors.primary),
      ],
    );
  }

  Widget _progressDot(int index, int currentStep, String label, Color color) {
    final active = currentStep >= index;
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: active
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: active ? color : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _progressLine(bool active) {
    return Container(
      height: 3,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _placeholder() => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(Icons.fastfood, color: Colors.grey[400], size: 26),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'No assignments yet',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Assigned requests from admin\nwill appear here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
        ),
      ],
    ),
  );

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
