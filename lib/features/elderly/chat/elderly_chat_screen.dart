import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/logging_service.dart';
import '../../../shared/services/gemini_service.dart';

/// AI Chat companion for elderly users.
/// UI shell — wire up Gemini API calls via backend team's service layer.
class ElderlyCharScreen extends StatefulWidget {
  const ElderlyCharScreen({super.key});

  @override
  State<ElderlyCharScreen> createState() => _ElderlyCharScreenState();
}

class _ElderlyCharScreenState extends State<ElderlyCharScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: "Hello! I'm CareSync, your AI companion.\nHow are you feeling today? You can ask me anything!",
      isAi: true,
    ),
  ];
  bool _isLoading = false;

  /// Build conversation history in the format Gemini expects.
  List<Map<String, String>> get _history {
    return _messages.map((m) => {
      'role': m.isAi ? 'model' : 'user',
      'text': m.text,
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isAi: false));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      logger.debug('Sending chat message to Gemini API: "$text"');
      final reply = await GeminiService.instance.sendChatMessage(
        message: text,
        history: _history,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isAi: true));
          _isLoading = false;
        });
        logger.success('Received reply from Gemini API');
      }
    } catch (e) {
      logger.error('Chat API failed', e);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: "Sorry, I'm having trouble connecting right now. Please try again in a moment.",
            isAi: true,
          ));
          _isLoading = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CareSync AI',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Your companion',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),

          // Input row
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.inter(
                        fontSize: AppTheme.elderlyBodyFontSize),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send_rounded,
                        color: Theme.of(context).colorScheme.onPrimary, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment:
          message.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isAi
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isAi ? 4 : 18),
            bottomRight: Radius.circular(message.isAi ? 18 : 4),
          ),
          border: message.isAi
              ? Border.all(
                  color: isDarkMode
                      ? Theme.of(context).dividerColor.withValues(alpha: 0.6)
                      : Theme.of(context).dividerColor,
                  width: 1.5,
                )
              : null,
        ),
        child: Text(
          message.text,
          softWrap: true,
          maxLines: null,
          style: GoogleFonts.inter(
            fontSize: AppTheme.elderlyBodyFontSize,
            color: message.isAi
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onPrimary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1.5,
          ),
        ),
        child: Text(
          'CareSync is typing...',
          style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  const _ChatMessage({required this.text, required this.isAi});
}
