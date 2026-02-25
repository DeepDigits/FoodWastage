import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBWh3mQ1DjJzcetpqtd7ZnxwxwCRbh6Zr8';
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
      "generationConfig": {"temperature": 0.2, "maxOutputTokens": 1024},
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
Analyse the food image provided and return **only** a valid JSON object (no markdown, no explanation outside the JSON).

The JSON must have these fields:
- "title": a short descriptive name for the food item (string)
- "description": a brief description ~ 1-2 sentences (string)
- "detected_items": list of food items you can identify (list of strings)
- "freshness": one of "fresh", "slightly_old", "spoiled" (string)
- "is_safe": whether this food is safe to donate (boolean)
- "category": one of "edible", "recyclable", "rejected" (string)
- "reason": a brief reason for the safety/category decision (string)
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

  /// Parse a JSON object from Gemini's text output, which may be wrapped in
  /// ```json ... ``` markers or contain leading/trailing text.
  static Map<String, dynamic> _extractJson(String text) {
    // Try to find JSON block in markdown code fence
    final fencePattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      return jsonDecode(fenceMatch.group(1)!) as Map<String, dynamic>;
    }

    // Try to find a raw JSON object
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) {
      return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    }

    throw Exception('Could not parse Gemini response as JSON:\n$text');
  }
}
