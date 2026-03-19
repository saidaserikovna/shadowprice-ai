import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/chat_models.dart';
import '../services/shadowprice_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final List<ChatMessageModel> _messages = [];

  bool _sending = false;
  List<String> _suggestedQuestions = const [
    'Is this a good price?',
    'Where is it cheaper?',
    'Should I buy now or wait?',
  ];

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageCtrl.text).trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _messages.add(ChatMessageModel.user(text));
      _messageCtrl.clear();
    });

    try {
      final reply = await context.read<ShadowPriceApiService>().askAssistant(
            question: text,
            history: _messages,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(ChatMessageModel.assistant(reply.answer));
        _suggestedQuestions = reply.suggestedQuestions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestAnalysis = context.watch<ShadowPriceApiService>().latestAnalysis;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ShadowPrice AI Chat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ShadowTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latestAnalysis == null
                        ? 'Ask general questions, or analyze a product first for grounded marketplace answers.'
                        : 'Current context: ${latestAnalysis.productName}',
                    style: const TextStyle(
                      color: ShadowTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                reverse: false,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  if (_messages.isEmpty) _buildEmptyState(),
                  ..._messages.map(_buildBubble),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !_sending
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: ShadowTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ShadowTheme.border),
                              ),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (_suggestedQuestions.isNotEmpty)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _suggestedQuestions
                      .map(
                        (question) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(question),
                            backgroundColor: ShadowTheme.surfaceLight,
                            labelStyle: const TextStyle(color: ShadowTheme.textPrimary),
                            onPressed: () => _sendMessage(question),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about price, stores, or whether to buy now',
                        prefixIcon: Icon(Icons.chat_bubble_outline, color: ShadowTheme.textMuted),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendMessage,
                      child: const Icon(Icons.arrow_upward),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking:',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '• Is this price good?\n• Which marketplace is cheapest?\n• Should I buy now or wait?\n• What risks should I check before buying?',
            style: TextStyle(
              color: ShadowTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessageModel message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? ShadowTheme.accent : ShadowTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: isUser ? null : Border.all(color: ShadowTheme.border),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : ShadowTheme.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
