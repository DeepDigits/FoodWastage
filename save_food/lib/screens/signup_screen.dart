import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// ─── Kerala Districts ────────────────────────────────────────────────────
const List<String> keralaDistricts = [
  'Thiruvananthapuram',
  'Kollam',
  'Pathanamthitta',
  'Alappuzha',
  'Kottayam',
  'Idukki',
  'Ernakulam',
  'Thrissur',
  'Palakkad',
  'Malappuram',
  'Kozhikode',
  'Wayanad',
  'Kannur',
  'Kasaragod',
];

const List<Map<String, String>> userTypes = [
  {'value': 'citizen', 'label': 'Citizen'},
  {'value': 'restaurant', 'label': 'Restaurant'},
  {'value': 'organization', 'label': 'Organization'},
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _selectedDistrict;
  String _selectedUserType = 'citizen';
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  Map<String, dynamic>? _errors;

  Future<void> _submit() async {
    setState(() => _errors = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await ApiService.signup({
        'full_name': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'pin_code': _pinCodeCtrl.text.trim(),
        'district': _selectedDistrict!.toLowerCase(),
        'full_address': _addressCtrl.text.trim(),
        'user_type': _selectedUserType,
        'password': _passwordCtrl.text,
        'confirm_password': _confirmPassCtrl.text,
      });
      if (!mounted) return;

      if (res['statusCode'] == 201) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Remove statusCode to leave only field errors
        res.remove('statusCode');
        setState(() => _errors = res);
      }
    } catch (e) {
      setState(
        () => _errors = {
          'non_field_errors': ['Network error. Please check your connection.'],
        },
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _fieldError(String field) {
    if (_errors == null) return null;
    final v = _errors![field];
    if (v is List && v.isNotEmpty) return v.first.toString();
    if (v is String) return v;
    return null;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCodeCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Background Gradient ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          // ─── Organic Decorations ─────────────────────────────
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // ─── Header ──────────────────────────────────
                  Icon(Icons.eco, color: AppColors.primary, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Join DEMETRA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create your account to start saving food',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Form Card ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_fieldError('non_field_errors') != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _fieldError('non_field_errors')!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          // ─── Full Name ───────────────────────────────
                          _buildTextField(
                            controller: _fullNameCtrl,
                            icon: Icons.badge_outlined,
                            label: 'Full Name',
                            capitalization: TextCapitalization.words,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              if (!RegExp(
                                r'^[a-zA-Z\s]+$',
                              ).hasMatch(v.trim())) {
                                return 'Only letters and spaces allowed';
                              }
                              if (v.trim().length < 2) {
                                return 'At least 2 characters';
                              }
                              return _fieldError('full_name');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Username ────────────────────────────────
                          _buildTextField(
                            controller: _usernameCtrl,
                            icon: Icons.person_outline,
                            label: 'Username',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Username is required';
                              }
                              if (v.trim().length < 3) {
                                return 'At least 3 characters';
                              }
                              return _fieldError('username');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Email ───────────────────────────────────
                          _buildTextField(
                            controller: _emailCtrl,
                            icon: Icons.email_outlined,
                            label: 'Email',
                            inputType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(
                                r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$',
                              ).hasMatch(v.trim())) {
                                return 'Enter a valid email';
                              }
                              return _fieldError('email');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Phone ───────────────────────────────────
                          _buildTextField(
                            controller: _phoneCtrl,
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            inputType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                                return 'Must be exactly 10 digits';
                              }
                              return _fieldError('phone');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── User Type Dropdown ──────────────────────
                          _buildDropdown(
                            value: _selectedUserType,
                            icon: Icons.group_outlined,
                            label: 'User Type',
                            items: userTypes,
                            onChanged: (v) =>
                                setState(() => _selectedUserType = v!),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Select user type'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // ─── District Dropdown ───────────────────────
                          DropdownButtonFormField<String>(
                            value: _selectedDistrict,
                            decoration: InputDecoration(
                              labelText: 'District',
                              prefixIcon: const Icon(
                                Icons.location_city_outlined,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                            items: keralaDistricts
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedDistrict = v),
                            validator: (v) =>
                                (v == null) ? 'Select your district' : null,
                          ),
                          const SizedBox(height: 16),

                          // ─── Pin Code ────────────────────────────────
                          _buildTextField(
                            controller: _pinCodeCtrl,
                            icon: Icons.pin_drop_outlined,
                            label: 'Pin Code',
                            inputType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Pin code is required';
                              }
                              if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                                return 'Must be exactly 6 digits';
                              }
                              return _fieldError('pin_code');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Full Address ────────────────────────────
                          _buildTextField(
                            controller: _addressCtrl,
                            icon: Icons.home_outlined,
                            label: 'Full Address',
                            maxLines: 3,
                            capitalization: TextCapitalization.sentences,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Address is required';
                              }
                              if (v.trim().length < 10) {
                                return 'Please enter a more detailed address';
                              }
                              return _fieldError('full_address');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Password ────────────────────────────────
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 8) return 'At least 8 characters';
                              return _fieldError('password');
                            },
                          ),
                          const SizedBox(height: 16),

                          // ─── Confirm Password ────────────────────────
                          TextFormField(
                            controller: _confirmPassCtrl,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.background.withOpacity(0.5),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirm your password';
                              }
                              if (v != _passwordCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return _fieldError('confirm_password');
                            },
                          ),
                          const SizedBox(height: 32),

                          // ─── Submit ──────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      textCapitalization: capitalization,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.background.withOpacity(0.5),
      ),
      validator: validator,
    );
  }
}

Widget _buildDropdown({
  required String value,
  required IconData icon,
  required String label,
  required List<Map<String, String>> items,
  required void Function(String?) onChanged,
  String? Function(String?)? validator,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    items: items
        .map(
          (t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!)),
        )
        .toList(),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      filled: true,
      fillColor: AppColors.background.withOpacity(0.5),
    ),
    validator: validator,
  );
}
