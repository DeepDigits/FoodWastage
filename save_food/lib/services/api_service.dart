import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your machine's IP if testing on a physical device
  static const String baseUrl = 'http://192.168.0.3:8000/api';

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Token $token',
    };
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ─── Auth ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));
    }
    return {'statusCode': res.statusCode, ...data};
  }

  static Future<Map<String, dynamic>> signup(
    Map<String, dynamic> payload,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/signup/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));
    }
    return {'statusCode': res.statusCode, ...data};
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/profile/'),
      headers: await _authHeaders(),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Food Donations ─────────────────────────────────────────────────

  /// Upload a food donation (multipart form).
  static Future<Map<String, dynamic>> donateFood({
    required File imageFile,
    required String title,
    required String description,
    required String foodType,
    required String category,
    required double latitude,
    required double longitude,
    required String address,
    String? expiryDate,
    int? safetyHours,
    required Map<String, dynamic> geminiAnalysis,
    required bool isSafe,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/donate/');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Token $token';

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['food_type'] = foodType;
    request.fields['category'] = category;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['address'] = address;
    request.fields['is_safe'] = isSafe.toString();
    request.fields['gemini_analysis'] = jsonEncode(geminiAnalysis);

    if (expiryDate != null) {
      request.fields['expiry_date'] = expiryDate;
    }
    if (safetyHours != null) {
      request.fields['safety_hours'] = safetyHours.toString();
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    return {'statusCode': streamed.statusCode, ...data};
  }

  /// All safe donations (public feed).
  static Future<List<dynamic>> getDonations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/donations/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  /// Current user's donations.
  static Future<List<dynamic>> getMyDonations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/my-donations/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  // ─── Buy Requests ───────────────────────────────────────────────────

  /// Send a buy request for a donation.
  static Future<Map<String, dynamic>> sendBuyRequest({
    required int donationId,
    String message = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-request/'),
      headers: await _authHeaders(),
      body: jsonEncode({'donation': donationId, 'message': message}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...data};
  }

  /// Check if current user already sent a request for this donation.
  static Future<Map<String, dynamic>> checkBuyRequest(int donationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/buy-requests/check/$donationId/'),
      headers: await _authHeaders(),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Get all buy requests sent by the current user.
  static Future<List<dynamic>> getSentRequests() async {
    final res = await http.get(
      Uri.parse('$baseUrl/buy-requests/sent/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  /// Get all buy requests received for the current user's donations.
  static Future<List<dynamic>> getReceivedRequests() async {
    final res = await http.get(
      Uri.parse('$baseUrl/buy-requests/received/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  /// Accept or reject a buy request.
  static Future<Map<String, dynamic>> respondBuyRequest({
    required int requestId,
    required String action, // 'accept' or 'reject'
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-requests/$requestId/respond/'),
      headers: await _authHeaders(),
      body: jsonEncode({'action': action}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...data};
  }

  // ─── Collector ──────────────────────────────────────────────────────

  /// Login as a food waste collector.
  static Future<Map<String, dynamic>> collectorLogin(
    String username,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/collector/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));
      await prefs.setString('collector', jsonEncode(data['collector']));
      await prefs.setBool('isCollector', true);
    }
    return {'statusCode': res.statusCode, ...data};
  }

  /// Get assigned requests for the logged-in collector.
  static Future<List<dynamic>> getCollectorDashboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/collector/dashboard/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    return [];
  }

  /// Verify OTP for a buy request (collector).
  static Future<Map<String, dynamic>> verifyCollectorOTP({
    required int requestId,
    required String otp,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/collector/verify-otp/$requestId/'),
      headers: await _authHeaders(),
      body: jsonEncode({'otp': otp}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...data};
  }

  /// Check if current user is a collector.
  static Future<bool> isCollector() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isCollector') ?? false;
  }

  /// Get collector data from SharedPreferences.
  static Future<Map<String, dynamic>?> getCollector() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('collector');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('collector');
    await prefs.remove('isCollector');
  }
}
