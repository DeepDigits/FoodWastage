import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/api_service.dart';
import 'camera_screen.dart';

class DonateFormScreen extends StatefulWidget {
  const DonateFormScreen({super.key});

  @override
  State<DonateFormScreen> createState() => _DonateFormScreenState();
}

class _DonateFormScreenState extends State<DonateFormScreen> {
  // ── Form state ──────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _imageFile;
  String _foodType = 'packed'; // packed | homecooked | organic
  Position? _position;
  String? _address;
  bool _locationLoading = false;

  // Gemini analysis
  bool _analysing = false;
  Map<String, dynamic>? _analysis;
  String? _analysisError;

  // Submit
  bool _submitting = false;

  // ── Lifecycle ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    setState(() => _locationLoading = true);
    try {
      // 1) Request permission via permission_handler (plays nice with MIUI)
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission denied. Enable it in App Settings.',
              ),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        setState(() {
          _address = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }
      if (!status.isGranted) {
        setState(() {
          _address = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }

      // 2) Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _address = 'Location services are disabled. Please enable GPS.';
          _locationLoading = false;
        });
        return;
      }

      // 3) Get current position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final p = placemarks.isNotEmpty ? placemarks.first : null;
      setState(() {
        _position = pos;
        _address = p != null
            ? '${p.street}, ${p.locality}, ${p.administrativeArea} ${p.postalCode}'
            : '${pos.latitude}, ${pos.longitude}';
        _locationLoading = false;
      });
    } catch (e) {
      setState(() {
        _address = 'Could not get location';
        _locationLoading = false;
      });
    }
  }

  // ── Camera ──────────────────────────────────────────────────────────
  Future<void> _captureImage() async {
    // Request permission HERE (before navigation) so no system dialog
    // fires mid-navigation and drops the debug connection.
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera permission denied. Enable it in App Settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required.')),
      );
      return;
    }

    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _imageFile = result;
        _analysis = null;
        _analysisError = null;
      });
    }
  }

  // ── Gemini analysis ─────────────────────────────────────────────────
  Future<void> _runAnalysis() async {
    if (_imageFile == null) return;
    setState(() {
      _analysing = true;
      _analysisError = null;
      _analysis = null;
    });
    try {
      final result = await GeminiService.analyseFood(
        imageFile: _imageFile!,
        foodType: _foodType,
      );
      setState(() {
        _analysis = result;
        _analysing = false;
        // Auto-fill title/desc from analysis if empty
        if (_titleCtrl.text.isEmpty && result['title'] != null) {
          _titleCtrl.text = result['title'];
        }
        if (_descCtrl.text.isEmpty && result['description'] != null) {
          _descCtrl.text = result['description'];
        }
      });

      // ── Post-analysis alerts ──

      // Gemini response could not be parsed → show error and clear
      if (result['parse_error'] == true) {
        setState(() {
          _analysis = null;
          _analysisError =
              'Could not analyse the image. Please retake the photo '
              'with better lighting and try again.';
        });
        return;
      }

      // Not a food item at all → block submission immediately
      if (result['is_food'] == false) {
        _showAlert(
          'Not a Food Item',
          'The image does not appear to contain food or a food product. '
              'Only food items are accepted for donation. '
              'Please retake the photo.',
          isWarning: true,
        );
        // Clear the captured image so the user must retake
        setState(() {
          _imageFile = null;
          _analysis = null;
        });
        return;
      }

      if (_foodType == 'packed' && result['expiry_detected'] == false) {
        _showAlert(
          'Expiry Date Not Detected',
          'The expiry date could not be read from the packaging. '
              'Please ensure the expiry date is clearly visible and try again, '
              'or enter it manually.',
          isWarning: true,
        );
      }

      if (result['is_safe'] == false) {
        _showAlert(
          'Food Not Safe for Donation',
          result['reason'] ?? 'This food item has been flagged as unsafe.',
          isWarning: true,
        );
      }
    } catch (e) {
      setState(() {
        _analysisError = e.toString();
        _analysing = false;
      });
    }
  }

  void _showAlert(String title, String message, {bool isWarning = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
              color: isWarning ? Colors.orange : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Submit to backend ───────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a food image first')),
      );
      return;
    }
    if (_analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please run AI analysis before submitting'),
        ),
      );
      return;
    }
    if (_analysis!['is_safe'] == false) {
      _showAlert(
        'Cannot Donate',
        'This food item has been classified as unsafe and cannot be donated.\n\n'
            'Reason: ${_analysis!['reason'] ?? 'Unknown'}',
        isWarning: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ApiService.donateFood(
        imageFile: _imageFile!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        foodType: _foodType,
        category: _analysis!['category'] ?? 'edible',
        latitude: _position?.latitude ?? 0,
        longitude: _position?.longitude ?? 0,
        address: _address ?? '',
        expiryDate: _analysis!['expiry_date'],
        safetyHours: _analysis!['safety_hours'],
        geminiAnalysis: _analysis!,
        isSafe: _analysis!['is_safe'] ?? true,
      );

      if (!mounted) return;
      if (result['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Food donated successfully! 🎉'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true); // true = donated
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['detail'] ?? 'Unknown error'}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 24),
                    _buildFoodTypeSelector(),
                    const SizedBox(height: 24),
                    _buildLocationCard(),
                    const SizedBox(height: 24),
                    _buildAnalysisButton(),
                    if (_analysing) _buildAnalysingIndicator(),
                    if (_analysisError != null) _buildAnalysisError(),
                    if (_analysis != null) ...[
                      const SizedBox(height: 16),
                      _buildAnalysisResults(),
                    ],
                    const SizedBox(height: 24),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildDescField(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Donate Food',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
    );
  }

  // ── Image Capture ───────────────────────────────────────────────────
  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _captureImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_imageFile!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Retake',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to capture food image',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live camera capture required',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Food Type Selector ──────────────────────────────────────────────
  Widget _buildFoodTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Type',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _foodTypeChip('packed', 'Packed', Icons.inventory_2_outlined),
            const SizedBox(width: 10),
            _foodTypeChip(
              'homecooked',
              'Home Cooked',
              Icons.restaurant_outlined,
            ),
            const SizedBox(width: 10),
            _foodTypeChip('organic', 'Organic', Icons.eco_outlined),
          ],
        ),
      ],
    );
  }

  Widget _foodTypeChip(String value, String label, IconData icon) {
    final selected = _foodType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _foodType = value;
          _analysis = null;
          _analysisError = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Location Card ───────────────────────────────────────────────────
  Widget _buildLocationCard() {
    final now = DateTime.now();
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Location & Time',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _locationLoading
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Fetching location...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _address ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                dateFmt,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_position != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.gps_fixed, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Analyse Button ──────────────────────────────────────────────────
  Widget _buildAnalysisButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (_imageFile == null || _analysing) ? null : _runAnalysis,
        icon: const Icon(Icons.auto_awesome, size: 20),
        label: Text(
          _analysis != null ? 'Re-analyse with AI' : 'Analyse with AI',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildAnalysingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'Gemini AI is analysing your food...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisError() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _analysisError!,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Analysis Results ────────────────────────────────────────────────
  Widget _buildAnalysisResults() {
    final a = _analysis!;
    final isSafe = a['is_safe'] == true;
    final category = a['category'] ?? 'unknown';
    final freshness = a['freshness'] ?? 'unknown';

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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSafe
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: const Color(0xFF7C4DFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Safety badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSafe
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSafe ? Icons.verified : Icons.dangerous,
                  size: 18,
                  color: isSafe ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  isSafe ? 'Safe to Donate' : 'Not Safe',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSafe ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category
          _analysisRow(
            categoryIcon,
            'Category',
            category.toUpperCase(),
            categoryColor,
          ),
          const SizedBox(height: 8),

          // Freshness
          _analysisRow(
            Icons.spa,
            'Freshness',
            freshness,
            AppColors.textPrimary,
          ),
          const SizedBox(height: 8),

          // Detected items
          if (a['detected_items'] != null) ...[
            _analysisRow(
              Icons.fastfood,
              'Detected',
              (a['detected_items'] as List).join(', '),
              AppColors.textPrimary,
            ),
            const SizedBox(height: 8),
          ],

          // Expiry (packed)
          if (_foodType == 'packed') ...[
            _analysisRow(
              Icons.event,
              'Expiry Date',
              a['expiry_detected'] == true
                  ? a['expiry_date'] ?? 'Detected'
                  : 'Not detected',
              a['expiry_detected'] == true
                  ? AppColors.textPrimary
                  : Colors.orange,
            ),
            const SizedBox(height: 8),
          ],

          // Safety hours (homecooked)
          if (_foodType == 'homecooked' && a['safety_hours'] != null) ...[
            _analysisRow(
              Icons.timer,
              'Safe for',
              '${a['safety_hours']} hours',
              AppColors.primary,
            ),
            const SizedBox(height: 8),
          ],

          // Reason
          if (a['reason'] != null) ...[
            const SizedBox(height: 4),
            Text(
              a['reason'],
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analysisRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  // ── Title & Description Fields ──────────────────────────────────────
  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Title',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleCtrl,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Fresh homemade biryani',
            prefixIcon: Icon(
              Icons.fastfood_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
        ),
      ],
    );
  }

  Widget _buildDescField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descCtrl,
          style: GoogleFonts.poppins(fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe the food, quantity, etc.',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.description_outlined,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please enter a description'
              : null,
        ),
      ],
    );
  }

  // ── Submit Button ───────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    final canSubmit =
        _analysis != null && _analysis!['is_safe'] == true && !_submitting;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'Donate Now',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
