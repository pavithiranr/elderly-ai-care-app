import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
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
      final reply = await GeminiService.instance.sendChatMessage(
        message: text,
        history: _history,
      );
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isAi: true));
          _isLoading = false;
        });
      }
    } catch (e) {
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
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppTheme.primaryBlue,
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
                      fontSize: 11, color: AppTheme.accentGreen),
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
            color: AppTheme.surfaceWhite,
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
                          fontSize: 16, color: AppTheme.textLight),
                      filled: true,
                      fillColor: AppTheme.backgroundGray,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
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
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
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
          color: message.isAi ? AppTheme.surfaceWhite : AppTheme.primaryBlue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isAi ? 4 : 18),
            bottomRight: Radius.circular(message.isAi ? 18 : 4),
          ),
          border: message.isAi
              ? Border.all(color: AppTheme.divider)
              : null,
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: AppTheme.elderlyBodyFontSize,
            color: message.isAi ? AppTheme.textDark : Theme.of(context).colorScheme.onPrimary,
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
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(
          'CareSync is typing...',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppTheme.textLight),
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
