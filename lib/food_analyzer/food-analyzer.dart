import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class FoodAnalysis {
  final String label;         // "healthy" | "not_healthy" | "uncertain"
  final int score;            // 0..10
  final String action;        // "eat" | "limit" | "avoid"
  final String calories;
  final List<String> reasons; // short bullets
  final List<String> tips;    // safer swaps

  FoodAnalysis({
    required this.label,
    required this.score,
    required this.action,
    required this.calories,
    required this.reasons,
    required this.tips,
  });

  factory FoodAnalysis.fromJson(Map<String, dynamic> j) {
    return FoodAnalysis(
      label: (j["label"] ?? "uncertain").toString(),
      score: (j["score"] is int) ? j["score"] : int.tryParse("${j["score"]}") ?? 0,
      action: (j["action"] ?? "limit").toString(),
      calories: (j["calories"] ?? "limit" ).toString(),
      reasons: (j["reasons"] as List?)?.map((e) => "$e").toList() ?? const [],
      tips: (j["tips"] as List?)?.map((e) => "$e").toList() ?? const [],
    );
  }
}

class FoodAnalyzer {
  final GenerativeModel _model;

  FoodAnalyzer({required String apiKey})
      : _model = GenerativeModel(
    // Use a multimodal model (text+image). Example models are shown in Gemini docs. :contentReference[oaicite:3]{index=3}
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
  );

  Future<FoodAnalysis> analyzeFoodImage({
    required Uint8List bytes,
    required String mimeType, // "image/jpeg" or "image/png"
  }) async {
    final prompt = '''
You are a food label assistant. Analyze the food in the image.

Return ONLY valid JSON (no markdown) with exactly:
{
  "label": "healthy" | "not_healthy" | "uncertain",
  "score": 0-10,
  "action": "eat" | "limit" | "avoid",
  "calories":"...",
  "reasons": ["...","...","..."],
  "tips": ["...","..."]
}

Rules:
- If you cannot identify the food, use label "uncertain" and explain in reasons.
- Keep reasons short and practical.
- Do NOT give medical diagnosis. Avoid absolute claims.
''';

    final content = [
      Content.multi([
        DataPart(mimeType, bytes),
        TextPart(prompt),
      ])
    ];

    final resp = await _model.generateContent(content);
    final text = (resp.text ?? "").trim();

    // Robust JSON extraction: sometimes models add extra text; try to slice first {...} block.
    final jsonStr = _extractFirstJsonObject(text);
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return FoodAnalysis.fromJson(map);
  }

  String _extractFirstJsonObject(String input) {
    final start = input.indexOf('{');
    final end = input.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      // fallback: force empty uncertain response
      return json.encode({
        "label": "uncertain",
        "score": 0,
        "action": "limit",
        "calories": "limit",
        "reasons": ["Could not parse the model response as JSON."],
        "tips": ["Try taking a clearer photo with good lighting."]
      });
    }
    return input.substring(start, end + 1);
  }
}
