import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBOOmQ7ju0mFnWUHTEmd5pT28eo2TvpEVY';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Analyse a food image using Gemini Vision.
  ///
  /// [imageFile]  – the photo captured by the user.
  /// [foodType]   – one of: packed, homecooked, organic.
  ///
  /// Returns a structured JSON map with:
  ///   title, description, category (edible / recyclable / rejected),
  ///   is_safe (bool), expiry_date (if packed), safety_hours (if homecooked),
  ///   detected_items, freshness, reason
  static Future<Map<String, dynamic>> analyseFood({
    required File imageFile,
    required String foodType,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final prompt = _buildPrompt(foodType);

    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.1,
        "maxOutputTokens": 1024,
        "response_mime_type": "application/json",
      },
    };

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    // Extract JSON from the response (Gemini sometimes wraps in markdown)
    return _extractJson(text);
  }

  static String _buildPrompt(String foodType) {
    final common = '''
You are a food safety analyst AI for a zero-waste food donation app called DEMETRA.
Analyse the image provided and return **only** a valid JSON object.
Do NOT include markdown fences, backticks, or any text outside the JSON object.

The JSON must have these exact fields:
- "is_food": true if the image contains food or a food product, false otherwise (boolean)
- "title": a short descriptive name for the item (string, or null if not food)
- "description": a 1-2 sentence description (string, or null if not food)
- "detected_items": list of items visible in the image (list of strings)
- "freshness": one of "fresh", "slightly_old", "spoiled", or null if not food (string)
- "is_safe": whether this food is safe to donate — set false if not food (boolean)
- "category": one of "edible", "recyclable", "rejected" (string)
- "reason": brief reason for the decision (string)

IMPORTANT: If the image does NOT show food (e.g. a person, object, scene, non-food item), set:
  is_food=false, is_safe=false, category="rejected",
  reason="Image does not contain a food item."
''';

    if (foodType == 'packed') {
      return '''
$common
Additional rules for PACKED food:
- Try to read any expiry/best-before date visible on the packaging using OCR.
- Add field "expiry_date" (string, format YYYY-MM-DD) if detected, otherwise null.
- Add field "expiry_detected" (boolean) – true if you could read an expiry date.
- If the expiry date has passed, set is_safe=false, category="rejected".
- If no expiry date is visible, set "expiry_detected": false.
- Add field "safety_hours": null (not applicable for packed food).
''';
    } else if (foodType == 'homecooked') {
      return '''
$common
Additional rules for HOME-COOKED food:
- There won't be an expiry date label.
- Add field "expiry_date": null.
- Add field "expiry_detected": null.
- Estimate how many hours this food can remain safe for consumption based on what you see.
- Add field "safety_hours" (integer, typically 2-12 hours depending on the food type).
- If the food appears spoiled, set is_safe=false, category="rejected".
''';
    } else {
      // organic
      return '''
$common
Additional rules for ORGANIC / RAW food (fruits, vegetables, raw produce):
- Add field "expiry_date": null.
- Add field "expiry_detected": null.
- Add field "safety_hours": null.
- Carefully inspect for signs of rot, mold, excessive browning, or insect damage.
- If the organic food appears bad/spoiled/rotten, set is_safe=false and category="rejected".
- If it appears edible, set category="edible". If only usable for composting/recycling, set category="recyclable".
''';
    }
  }

  /// Robustly extract a JSON object from Gemini output.
  /// When response_mime_type=application/json is set the text should already
  /// be clean JSON, but we still handle all wrapping variants as a fallback.
  static Map<String, dynamic> _extractJson(String text) {
    // 0. Strip <think>...</think> blocks produced by thinking models
    var cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .trim();

    // 1. Direct parse (works when response_mime_type=application/json is set)
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // 2. Strip markdown fences (```json ... ``` or ``` ... ```)
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fenceMatch = fencePattern.firstMatch(cleaned);
    final candidate1 = fenceMatch?.group(1)?.trim() ?? '';

    // 3. Find the outermost { ... } block (handles leading/trailing text)
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(cleaned);
    final candidate2 = jsonMatch?.group(0)?.trim() ?? '';

    // Try each candidate and return first that parses successfully
    for (final raw in [candidate1, candidate2]) {
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // try next candidate
      }
    }

    // All strategies failed – return a structured error map so the
    // caller can show a friendly message instead of crashing.
    return {
      'is_food': false,
      'is_safe': false,
      'category': 'rejected',
      'title': null,
      'description': null,
      'detected_items': <String>[],
      'freshness': null,
      'expiry_date': null,
      'expiry_detected': false,
      'safety_hours': null,
      'reason':
          'Could not analyse the image. Please retake the photo '
          'with better lighting and try again.',
      'parse_error': true,
    };
  }
}
