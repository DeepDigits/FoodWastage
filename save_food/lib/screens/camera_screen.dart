import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart' show appCameras;
import '../theme/app_theme.dart';

/// Full in-app camera. Returns a [File] on success, null on cancel.
/// Uses [appCameras] pre-initialised in main() so Android never needs
/// to launch a separate Activity (which drops the debug connection).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _ctrl;
  int _cameraIndex = 0;
  bool _ready = false;
  bool _capturing = false;
  String? _error;
  File? _capturedFile; // non-null = show confirm screen

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(index: _cameraIndex);
    }
  }

  // ── Init ─────────────────────────────────────────────────────────────
  Future<void> _initCamera({int index = 0}) async {
    // Permission is already granted by DonateFormScreen before navigation.
    // Do NOT call Permission.camera.request() here – that spawns an Activity
    // and drops the debug / release connection.
    if (appCameras.isEmpty) {
      setState(() => _error = 'No cameras found on this device.');
      return;
    }

    // 3. Safely dispose old controller
    final old = _ctrl;
    _ctrl = null;
    if (mounted) setState(() => _ready = false);
    await old?.dispose();

    _cameraIndex = index.clamp(0, appCameras.length - 1);

    final ctrl = CameraController(
      appCameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await ctrl.initialize();
      await ctrl
          .lockCaptureOrientation(DeviceOrientation.portraitUp)
          .catchError((_) {});
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _ready = true;
        _error = null;
        _capturedFile = null;
      });
    } catch (e) {
      await ctrl.dispose();
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (appCameras.length < 2) return;
    await _initCamera(index: _cameraIndex == 0 ? 1 : 0);
  }

  // ── Capture ──────────────────────────────────────────────────────────
  Future<void> _capture() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final xFile = await ctrl.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = File(xFile.path);
        _capturing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _retake() => setState(() => _capturedFile = null);
  void _usePhoto() => Navigator.pop(context, _capturedFile);

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _capturedFile != null ? _buildConfirm() : _buildLiveView(),
      ),
    );
  }

  // ── Live camera view ──────────────────────────────────────────────────
  Widget _buildLiveView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview / loading / error
        if (_ready && _ctrl != null)
          _buildCameraPreview()
        else if (_error != null)
          _buildError()
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconBtn(
                  Icons.arrow_back_ios_new,
                  () => Navigator.pop(context),
                ),
                Text(
                  'Scan Food',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                _iconBtn(Icons.flip_camera_android, _flipCamera),
              ],
            ),
          ),
        ),

        // Guide frame
        if (_ready)
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  _corner(top: 0, left: 0, tl: true),
                  _corner(top: 0, right: 0, tr: true),
                  _corner(bottom: 0, left: 0, bl: true),
                  _corner(bottom: 0, right: 0, br: true),
                ],
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(40, 12, 40, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Place food inside the frame',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 48),
                      // Shutter
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: _capturing
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      ),
                      _iconBtn(Icons.flip_camera_android_outlined, _flipCamera),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final ctrl = _ctrl!;
    final prev = ctrl.value.previewSize;
    if (prev == null) return const SizedBox.shrink();
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: prev.height,
            height: prev.width,
            child: CameraPreview(ctrl),
          ),
        ),
      ),
    );
  }

  // ── Confirm screen ────────────────────────────────────────────────────
  Widget _buildConfirm() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_capturedFile!, fit: BoxFit.cover),

        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Back
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _iconBtn(
                Icons.arrow_back_ios_new,
                () => Navigator.pop(context),
              ),
            ),
          ),
        ),

        // Retake / Use
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Use this photo?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _retake,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            'Retake',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _usePhoto,
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            'Use Photo',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Error view ────────────────────────────────────────────────────────
  Widget _buildError() {
    final isPermanent = _error?.contains('permanently') ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (isPermanent)
              ElevatedButton(
                onPressed: openAppSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  'Open App Settings',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              )
            else
              TextButton(
                onPressed: _initCamera,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool tl = false,
    bool tr = false,
    bool bl = false,
    bool br = false,
  }) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: (tl || tr)
              ? const BorderSide(color: AppColors.primaryLight, width: 3)
              : BorderSide.none,
          bottom: (bl || br)
              ? const BorderSide(color: AppColors.primaryLight, width: 3)
              : BorderSide.none,
          left: (tl || bl)
              ? const BorderSide(color: AppColors.primaryLight, width: 3)
              : BorderSide.none,
          right: (tr || br)
              ? const BorderSide(color: AppColors.primaryLight, width: 3)
              : BorderSide.none,
        ),
      ),
    ),
  );
}
