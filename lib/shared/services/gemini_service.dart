import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/services/logging_service.dart';

/// Calls Google Gemini API to generate AI summaries about elderly patient care.
/// 
/// Architecture Notes:
/// - Uses Gemini 2.5 Flash model (stable free tier, 5 RPM limit)
/// - Gemini 2.0 series was deprecated March 3, 2026 (limit set to 0 for free tier)
/// - Gemini 3.1 Flash Lite not yet available on v1beta generateContent endpoint
/// - All API calls go through [_makeApiRequest] which enforces:
///   * Exponential backoff retry (1s, 2s, 4s, 8s) for 429 errors
///   * Response validation (checks for empty candidates list)
///   * Centralized error handling
/// - IMPORTANT: Never include real patient names in prompts (use IDs/nicknames only)
/// - TODO: Move API key to backend server for production (Firebase Functions, etc.)
/// - TIP: Link a Billing Account in Google AI Studio (even without spending) to avoid "limit: 0" errors
class GeminiService {
  GeminiService._() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    logger.debug('GeminiService initialized - API key loaded: ${key.isNotEmpty ? "✅ (${key.length} chars)" : "❌ EMPTY"}');
  }
  static final GeminiService instance = GeminiService._();

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Generate a concise health summary for a caregiver dashboard.
  /// 
  /// Takes a list of recent activities/events and returns a brief, 
  /// AI-generated paragraph summarizing the elderly person's status.
  /// Protected by exponential backoff retry logic and response validation.
  Future<String> generateHealthSummary(List<String> recentEvents) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final prompt = _buildHealthSummaryPrompt(recentEvents);
    final result = await _makeApiRequest({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 500,
        'topP': 0.9,
      },
    });
    return _validateSummary(result);
  }

  /// Build a focused prompt for health summaries.
  String _buildHealthSummaryPrompt(List<String> events) {
    final eventsList = events.join('\n• ');
    return '''TASK: Write a 1-2 sentence health status report for a caregiver dashboard.
STRICT RULES:
- Start the response directly with the patient's health condition (e.g. "The patient..." or "[Name] is...")
- Do NOT begin with greetings like "Good morning", "Hello", "Hi", or any salutation
- Use only the data listed below — do not invent or assume details
- Be factual, concise, and professional

PATIENT DATA:
• $eventsList

HEALTH STATUS REPORT (start with patient condition, no greeting):''';
  }

  /// Send a chat message as an elderly companion.
  /// [history] is a list of {role: 'user'|'model', text: '...'} maps.
  /// Returns Gemini's reply text.
  /// Protected by exponential backoff retry logic and response validation.
  Future<String> sendChatMessage({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    // Build conversation turns from history
    final contents = <Map<String, dynamic>>[];
    for (final turn in history) {
      contents.add({
        'role': turn['role'],
        'parts': [{'text': turn['text']}],
      });
    }
    // Append the new user message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    return _makeApiRequest({
      'system_instruction': {
        'parts': [
          {
            'text':
                'You are CareSync, a warm, patient, and friendly AI companion for elderly users. '
                'Keep responses concise (2-3 sentences max), use simple language, '
                'and be encouraging. Gently remind users about health habits when relevant. '
                'Never give medical diagnoses. If the user seems distressed, suggest contacting their caregiver.',
          }
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.75,
        'maxOutputTokens': 2048,
        'topP': 0.9,
      },
    });
  }

  /// Consolidated API request handler with response validation and retry logic.
  /// All public methods route through this to ensure consistent error handling.
  /// 
  /// Features:
  /// - Exponential backoff retry for 429 errors (1s, 2s, 4s, 8s)
  /// - Response validation: checks for empty candidates list (safety filter blocks)
  /// - Centralized error handling with proper API exception throwing
  /// - Uses official x-goog-api-key header authentication (not query parameter)
  Future<String> _makeApiRequest(Map<String, dynamic> requestBody) async {
    return _sendWithRetry(() async {
      logger.debug('Making Gemini API call to: $_baseUrl');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode(requestBody),
      );

      logger.debug('Gemini API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // CRITICAL: Validate response structure before accessing
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          logger.warning('Empty candidates list - likely blocked by safety filter');
          return "I'm sorry, I couldn't generate a response right now. Please try again.";
        }

        final parts = candidates[0]?['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          logger.warning('Empty parts list in response');
          return "I'm sorry, I couldn't generate a response right now. Please try again.";
        }

        final text = parts[0]['text']?.toString() ?? '';
        return text.trim();
      } else {
        final body = response.body;
        logger.error('Gemini API error response: $body', null);
        // Pass full body so retry logic can detect daily quota vs per-minute rate limit
        throw _ApiException(
          statusCode: response.statusCode,
          message: body,
        );
      }
    }, maxRetries: 4);
  }

  /// Generic retry wrapper with exponential backoff for rate limits (429) and server errors (503).
  /// Waits: 1s → 2s → 4s → 8s before each retry attempt.
  /// 
  /// Retryable errors:
  /// - 429: Rate limit / resource exhausted
  /// - 503: Service unavailable (temporary high demand)
  /// 
  /// Special handling for "limit: 0" errors (model deprecated for free tier):
  /// - Does NOT retry if the error indicates the model's quota is permanently zero
  /// - Suggests billing account linkage as a workaround
  Future<T> _sendWithRetry<T>(
    Future<T> Function() request, {
    int maxRetries = 4,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } on _ApiException catch (e) {
        final errorMsg = e.message.toLowerCase();
        
        // Check for daily quota exhaustion (per-day limit, not per-minute rate limit)
        final isDailyQuota = errorMsg.contains('per_day') ||
            errorMsg.contains('generateRequestsPerDayPerProjectPerModel'.toLowerCase()) ||
            errorMsg.contains('limit: 0');
        if (isDailyQuota) {
          logger.error('Daily Gemini quota exhausted. Will not retry — try again tomorrow.');
          throw Exception('AI summary unavailable — daily quota reached. Try again tomorrow.');
        }
        
        // Retry on 429 (rate limit) and 503 (service unavailable)
        final isRetryable = e.statusCode == 429 || e.statusCode == 503;
        if (!isRetryable) {
          throw Exception('Gemini API error: ${e.message}');
        }

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 1s, 2s, 4s, 8s
          final delaySeconds = 1 << attempt; // 2^attempt
          final reason = e.statusCode == 429 ? 'Rate limited (429)' : 'Service unavailable (503)';
          logger.warning('$reason. Waiting ${delaySeconds}s before retry (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          // All retries exhausted
          throw Exception('Gemini API request failed after $maxRetries attempts. Please try again later.');
        }
      } catch (e) {
        // Non-API exceptions: rethrow immediately
        rethrow;
      }
    }
    throw Exception('Unknown error in retry logic');
  }

  /// Generate a daily health summary for a caregiver report.
  /// Accepts pre-formatted strings from today's check-in data.
  /// Protected by exponential backoff retry logic and response validation.
  ///
  /// NOTE: [patientName] should be a nickname or ID, NOT the real full name (privacy).
  Future<String> generateDailySummary({
    required String patientName,
    required List<String> events,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final eventsList = events.join('\n• ');
    final prompt =
        'TASK: Write a 2-3 sentence daily health report for a caregiver about their elderly patient.\n'
        'STRICT RULES:\n'
        '- Start directly with the patient\'s health condition (e.g. "The patient..." or "$patientName is...")\n'
        '- Do NOT begin with greetings, salutations, or "Good morning/afternoon/evening"\n'
        '- Mention mood, pain level, and medication adherence from the data provided\n'
        '- Flag any SOS alerts if present\n'
        '- Use only the data below — do not invent or assume anything\n\n'
        'PATIENT DATA FOR TODAY:\n• $eventsList\n\n'
        'DAILY HEALTH REPORT (begin with patient status, no greeting):';

    final result = await _makeApiRequest({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.65,
        'maxOutputTokens': 150,
        'topP': 0.9,
      },
    });
    return _validateSummary(result);
  }

  /// Rejects greeting-only or too-short Gemini responses.
  String _validateSummary(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    final startsWithGreeting = lower.startsWith('good morning') ||
        lower.startsWith('good afternoon') ||
        lower.startsWith('good evening') ||
        lower.startsWith('hello') ||
        lower.startsWith('hi ') ||
        lower.startsWith('hi,') ||
        lower.startsWith('hi!');
    if (startsWithGreeting || trimmed.length < 40) {
      logger.warning('Gemini returned invalid summary (greeting or too short): "$trimmed"');
      throw Exception('Gemini returned an unusable response');
    }
    return trimmed;
  }

  /// Generate medication reminder text.
  /// Protected by exponential backoff retry logic and response validation.
  Future<String> generateMedicationReminder(String medicationName, String dosage) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not configured in .env');
    }

    final prompt =
        'Write a brief, friendly medication reminder (1 sentence) for $dosage of $medicationName.';

    return _makeApiRequest({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 50,
      },
    });
  }
}

/// Custom exception for API errors to distinguish from other exceptions.
class _ApiException implements Exception {
  final int statusCode;
  final String message;
  _ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
