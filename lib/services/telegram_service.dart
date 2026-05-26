import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:drama_hub/config/app_config_service.dart';

/// Service responsible for sending form submissions to the admin's Telegram bot.
///
/// Bot token and chat ID are fetched from AppConfigService (app_config.json on GitHub).
/// Never hardcoded. Admin can rotate token anytime via admin panel — no app update needed.
///
/// Used by: SuggestDramaScreen, ReportProblemScreen
class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  String get _botToken => AppConfigService.instance.config.telegramBotToken;
  String get _chatId => AppConfigService.instance.config.telegramChatId;

  bool get _isConfigured => _botToken.isNotEmpty && _chatId.isNotEmpty;

  /// Sends a formatted message to the admin Telegram chat.
  /// Returns true on success, false on failure.
  Future<bool> sendMessage(String message) async {
    if (!_isConfigured) {
      if (kDebugMode) {
        debugPrint('TelegramService: bot token or chat ID not configured');
      }
      return false;
    }

    try {
      final uri = Uri.parse(
        'https://api.telegram.org/bot$_botToken/sendMessage',
      );

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': _chatId,
              'text': message,
              'parse_mode': 'HTML',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('TelegramService: message sent successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint(
            'TelegramService: failed — status ${response.statusCode}, body: ${response.body}',
          );
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TelegramService: error — $e');
      }
      return false;
    }
  }

  /// Builds and sends a Drama Suggestion message.
  Future<bool> sendDramaSuggestion({
    required String dramaName,
    required String language,
    String? whyAddIt,
    String? contact,
    required String appVersion,
    required String country,
  }) {
    final now = DateTime.now();
    final timestamp =
        '${_twoDigits(now.day)} ${_monthName(now.month)} ${now.year}, '
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';

    final buffer = StringBuffer();

    // Header row with emoji + timestamp on right
    buffer.writeln(
      '🎬 <b>Drama Suggestion</b>                    🕐 $timestamp',
    );
    buffer.writeln('─────────────────────────────');
    buffer.writeln('📌 <b>Drama Name:</b> $dramaName');
    buffer.writeln('🌐 <b>Language:</b> $language');

    if (whyAddIt != null && whyAddIt.trim().isNotEmpty) {
      buffer.writeln('💬 <b>Why add it:</b> ${whyAddIt.trim()}');
    }

    buffer.writeln('─────────────────────────────');

    if (contact != null && contact.trim().isNotEmpty) {
      buffer.writeln('👤 <b>Contact:</b> ${contact.trim()}');
    }

    buffer.writeln('📱 <b>App Version:</b> $appVersion');
    buffer.writeln('🌍 <b>Country:</b> $country');

    return sendMessage(buffer.toString().trimRight());
  }

  /// Builds and sends a Problem Report message.
  Future<bool> sendProblemReport({
    required String problemType,
    String? dramaEpisodeName,
    required String description,
    String? contact,
    required String appVersion,
    required String country,
  }) {
    final now = DateTime.now();
    final timestamp =
        '${_twoDigits(now.day)} ${_monthName(now.month)} ${now.year}, '
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';

    final buffer = StringBuffer();

    buffer.writeln(
      '🚨 <b>Problem Report</b>                       🕐 $timestamp',
    );
    buffer.writeln('─────────────────────────────');
    buffer.writeln('⚠️ <b>Problem Type:</b> $problemType');

    if (dramaEpisodeName != null && dramaEpisodeName.trim().isNotEmpty) {
      buffer.writeln('🎥 <b>Drama / Episode:</b> ${dramaEpisodeName.trim()}');
    }

    buffer.writeln('📝 <b>Description:</b> ${description.trim()}');
    buffer.writeln('─────────────────────────────');

    if (contact != null && contact.trim().isNotEmpty) {
      buffer.writeln('👤 <b>Contact:</b> ${contact.trim()}');
    }

    buffer.writeln('📱 <b>App Version:</b> $appVersion');
    buffer.writeln('🌍 <b>Country:</b> $country');

    return sendMessage(buffer.toString().trimRight());
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
