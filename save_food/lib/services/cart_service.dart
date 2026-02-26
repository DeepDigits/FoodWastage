import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple local cart backed by SharedPreferences.
/// Each item is stored as a JSON-encoded donation map.
class CartService {
  static const _key = 'cart_items';

  static Future<List<Map<String, dynamic>>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> addItem(Map<String, dynamic> donation) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    // Avoid duplicates by id
    final id = donation['id'];
    if (raw.any((e) {
      final d = jsonDecode(e) as Map<String, dynamic>;
      return d['id'] == id;
    }))
      return;
    raw.add(jsonEncode(donation));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> removeItem(int donationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      final d = jsonDecode(e) as Map<String, dynamic>;
      return d['id'] == donationId;
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<bool> isInCart(int donationId) async {
    final items = await getItems();
    return items.any((d) => d['id'] == donationId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }
}
