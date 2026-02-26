import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'food_detail_screen.dart';
import 'route_map_screen.dart';

/// Shows Sent and Received buy-request tabs (swipeable).
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _sent = [];
  List<Map<String, dynamic>> _received = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sent = await ApiService.getSentRequests();
      final received = await ApiService.getReceivedRequests();
      if (mounted) {
        setState(() {
          _sent = sent.cast<Map<String, dynamic>>();
          _received = received.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Accept / Reject ──────────────────────────────────────────────────
  Future<void> _respond(int requestId, String action) async {
    try {
      final res = await ApiService.respondBuyRequest(
        requestId: requestId,
        action: action,
      );
      if (res['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${action}ed'),
            backgroundColor: action == 'accept'
                ? AppColors.primary
                : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  // ── Map navigation ──────────────────────────────────────────────────
  void _openRouteMap(double lat, double lng, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RouteMapScreen(destLat: lat, destLng: lng, destLabel: title),
      ),
    );
  }

  // ====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Requests',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Sent (${_sent.length})'),
            Tab(text: 'Received (${_received.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabCtrl,
                children: [_buildSentTab(), _buildReceivedTab()],
              ),
            ),
    );
  }

  // ── Sent tab ─────────────────────────────────────────────────────────
  Widget _buildSentTab() {
    if (_sent.isEmpty) return _emptyState('No sent requests yet');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sent.length,
      itemBuilder: (_, i) => _sentCard(_sent[i]),
    );
  }

  Widget _sentCard(Map<String, dynamic> req) {
    final donTitle = req['donation_title'] ?? 'Untitled';
    final donImage = req['donation_image_url'];
    final donorName = req['donor_name'] ?? 'Unknown';
    final status = req['status'] ?? 'pending';
    final createdAt = req['created_at'] ?? '';
    final donationData = req['donation_data'] as Map<String, dynamic>?;
    final deliveryStatus = req['delivery_status'] ?? '';
    final receiverOtp = req['receiver_otp'] ?? '';
    final collectorName = req['collector_name'] ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.primary;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
    }

    return GestureDetector(
      onTap: donationData != null
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodDetailScreen(donation: donationData),
              ),
            ).then((_) => _load())
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: donImage != null
                      ? Image.network(
                          donImage,
                          width: 60,
                          height: 60,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Donor: $donorName',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
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
                        status[0].toUpperCase() + status.substring(1),
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
            // Delivery status + OTP for accepted requests
            if (status == 'accepted') ...[
              const SizedBox(height: 10),
              // Delivery status badge
              _deliveryStatusBanner(deliveryStatus),
              // Collector info
              if (collectorName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 15,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Collector: $collectorName',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              // Receiver OTP (visible to the requester)
              if (receiverOtp.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Delivery OTP',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              receiverOtp,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade800,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Share with\ncollector',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Received tab ─────────────────────────────────────────────────────
  Widget _buildReceivedTab() {
    if (_received.isEmpty) return _emptyState('No received requests yet');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _received.length,
      itemBuilder: (_, i) => _receivedCard(_received[i]),
    );
  }

  Widget _receivedCard(Map<String, dynamic> req) {
    final reqId = req['id'];
    final requesterName = req['requester_name'] ?? 'Unknown';
    final requesterPhone = req['requester_phone'] ?? '';
    final requesterAddress = req['requester_address'] ?? '';
    final requesterDistrict = req['requester_district'] ?? '';
    final donTitle = req['donation_title'] ?? 'Untitled';
    final donImage = req['donation_image_url'];
    final status = req['status'] ?? 'pending';
    final createdAt = req['created_at'] ?? '';
    final donationData = req['donation_data'] as Map<String, dynamic>?;
    final lat = donationData?['latitude'];
    final lng = donationData?['longitude'];
    final deliveryStatus = req['delivery_status'] ?? '';
    final senderOtp = req['sender_otp'] ?? '';
    final collectorName = req['collector_name'] ?? '';

    Color statusColor;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.primary;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Food item header
          GestureDetector(
            onTap: donationData != null
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FoodDetailScreen(donation: donationData),
                    ),
                  ).then((_) => _load())
                : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: donImage != null
                        ? Image.network(
                            donImage,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(size: 50),
                          )
                        : _placeholder(size: 50),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Requester details card
          Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requester',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                _detailRow(Icons.person_outline, requesterName),
                if (requesterPhone.isNotEmpty)
                  _detailRow(Icons.phone_outlined, requesterPhone),
                if (requesterDistrict.isNotEmpty)
                  _detailRow(Icons.location_city_outlined, requesterDistrict),
                if (requesterAddress.isNotEmpty)
                  _detailRow(Icons.home_outlined, requesterAddress),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                // View Location
                if (lat != null && lng != null)
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _openRouteMap(
                          (lat as num).toDouble(),
                          (lng as num).toDouble(),
                          donTitle,
                        ),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: Text(
                          'View Location',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey,
                          side: const BorderSide(color: Colors.blueGrey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (lat != null && lng != null && status == 'pending')
                  const SizedBox(width: 8),
                // Accept / Reject
                if (status == 'pending') ...[
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => _respond(reqId, 'accept'),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(
                          'Accept',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _respond(reqId, 'reject'),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Delivery status + Sender OTP for accepted requests
          if (status == 'accepted') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Delivery status banner
                  _deliveryStatusBanner(deliveryStatus),
                  // Collector info
                  if (collectorName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          size: 15,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Collector: $collectorName',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Sender OTP (visible to the donor)
                  if (senderOtp.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepOrange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            color: Colors.deepOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Pickup OTP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.deepOrange.shade700,
                                  ),
                                ),
                                Text(
                                  senderOtp,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.deepOrange.shade800,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Share with\ncollector',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.deepOrange.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Delivery Status Banner ────────────────────────────────────────
  Widget _deliveryStatusBanner(String deliveryStatus) {
    Color color;
    IconData icon;
    String label;
    switch (deliveryStatus) {
      case 'collected':
        color = Colors.blue;
        icon = Icons.inventory_2_rounded;
        label = 'Collected by worker';
        break;
      case 'delivered':
        color = AppColors.primary;
        icon = Icons.check_circle;
        label = 'Successfully Delivered';
        break;
      case 'waiting':
        color = Colors.orange;
        icon = Icons.hourglass_top;
        label = 'Waiting for collection';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
        label = 'Processing';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              deliveryStatus.isNotEmpty
                  ? deliveryStatus[0].toUpperCase() +
                        deliveryStatus.substring(1)
                  : '',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
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

  Widget _placeholder({double size = 60}) => Container(
    width: size,
    height: size,
    color: Colors.grey[200],
    child: Icon(Icons.fastfood, color: Colors.grey[400], size: size * 0.45),
  );

  Widget _emptyState(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          msg,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
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
