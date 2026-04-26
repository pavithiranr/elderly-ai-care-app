import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/logging_service.dart';

/// Calls backend Gemini API to generate AI summaries about elderly patient care.
/// 
/// Architecture:
/// - All calls route through a backend server (e.g., Cloud Run, Express, Firebase Functions)
/// - Backend uses Application Default Credentials (ADC) or service account for Gemini API access
/// - Flutter app sends requests to /gemini/* backend endpoints
/// - API key never stored or exposed in Flutter app
/// - IMPORTANT: Never include real patient names in prompts (use IDs/nicknames only)
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  /// Backend base URL — set to your actual backend server address
  /// For local development: 'http://10.29.107.22:8080' (your machine IP)
  /// For production: Cloud Run endpoint (https://caresync-backend-631057330468.us-central1.run.app)
  static const String _baseUrl = 'https://caresync-backend-631057330468.us-central1.run.app';

  /// Generate a concise health summary for a caregiver dashboard.
  /// 
  /// Takes a list of recent activities/events and returns a brief, 
  /// AI-generated paragraph summarizing the elderly person's status.
  Future<String> generateHealthSummary(List<String> recentEvents) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/summary'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'recentEvents': recentEvents}),
    );

    if (response.statusCode != 200) {
      logger.error('generateHealthSummary failed: ${response.body}', null);
      throw Exception('Health summary request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = data['summary']?.toString() ?? '';
    if (summary.isEmpty) {
      throw Exception('Empty summary response from backend');
    }
    return summary;
  }

  /// Send a chat message as an elderly companion.
  /// [history] is a list of {role: 'user'|'model', text: '...'} maps.
  /// Returns Gemini's reply text.
  Future<String> sendChatMessage({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'history': history,
      }),
    );

    if (response.statusCode != 200) {
      logger.error('sendChatMessage failed: ${response.body}', null);
      throw Exception('Chat request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = data['reply']?.toString() ?? '';
    if (reply.isEmpty) {
      throw Exception('Empty reply from backend');
    }
    return reply;
  }



  /// Generate a daily health summary for a caregiver report.
  /// Accepts pre-formatted strings from today's check-in data.
  ///
  /// NOTE: [patientName] should be a nickname or ID, NOT the real full name (privacy).
  Future<String> generateDailySummary({
    required String patientName,
    required List<String> events,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/daily-summary'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientName': patientName,
        'events': events,
      }),
    );

    if (response.statusCode != 200) {
      logger.error('generateDailySummary failed: ${response.body}', null);
      throw Exception('Daily summary request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = data['summary']?.toString() ?? '';
    if (summary.isEmpty) {
      throw Exception('Empty daily summary response from backend');
    }
    return summary;
  }

  /// Agentic 3-step care analysis — single API call, structured output.
  ///
  /// Asks Gemini to reason through all three steps in one response:
  ///   Step 1 — Signal Extractor  : parse raw events → structured health signals
  ///   Step 2 — Risk Assessor     : reason over signals → risk level + flags
  ///   Step 3 — Care Planner      : synthesise risk → actionable caregiver plan
  ///
  /// Output is delimited by [SIGNALS], [RISK], [PLAN] tags and parsed into
  /// [AgenticCareResult] so the UI can display the full reasoning chain.
  Future<AgenticCareResult> generateAgenticCareAnalysis(List<String> events) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/gemini/agentic-analysis'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'events': events}),
    );

    if (response.statusCode != 200) {
      logger.error('generateAgenticCareAnalysis failed: ${response.body}', null);
      throw Exception('Agentic analysis request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AgenticCareResult(
      signals: data['signals']?.toString() ?? '',
      riskAssessment: data['riskAssessment']?.toString() ?? '',
      carePlan: data['carePlan']?.toString() ?? '',
    );
  }

}

/// ─────────────────────────────────────────────────────────────────────────────
/// Data models (unchanged from original)
/// ─────────────────────────────────────────────────────────────────────────────

/// Result of the 3-step agentic care analysis pipeline.
class AgenticCareResult {
  final String signals;
  final String riskAssessment;
  final String carePlan;

  AgenticCareResult({
    required this.signals,
    required this.riskAssessment,
    required this.carePlan,
  });
}
