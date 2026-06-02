import 'dart:async';

import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/chatbot_api.dart';
import '../auth/auth_storage.dart';
import 'stomp_chat_client.dart';

class ChatbotScreen extends StatefulWidget {
  final String baseUrl;
  final String wsUrl; // e.g. "ws://localhost:8080/ws"
  final AuthStorage storage;

  const ChatbotScreen({
    super.key,
    required this.baseUrl,
    required this.wsUrl,
    required this.storage,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with SingleTickerProviderStateMixin {
  late final ChatbotApi _chatbotApi;
  late final StompChatClient _stomp;
  late final TabController _tabController;

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _messageScrollCtrl = ScrollController();

  // Typing debounce
  Timer? _typingDebounce;
  bool _remoteTyping = false; // admin is typing
  Timer? _remoteTypingTimeout;

  ChatbotBootstrapResponse? _bootstrap;
  List<ChatbotConversationSummary> _conversations = const [];
  ChatbotConversationDetail? _activeConversation;
  ChatbotCategory? _selectedCategory;
  List<ChatbotFaqItem> _currentItems = const [];
  final List<ChatbotFaqItem> _faqPath = [];

  bool _loading = false;
  bool _sending = false;
  bool _stompConnected = false;
  bool _showResolutionActions = false;
  String? _error;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _chatbotApi = ChatbotApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _stomp = StompChatClient(wsUrl: widget.wsUrl);
    _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
    _connectStomp();
    _loadInitial();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _messageScrollCtrl.dispose();
    _tabController.dispose();
    _typingDebounce?.cancel();
    _remoteTypingTimeout?.cancel();
    _stomp.disconnect();
    super.dispose();
  }

  // ─────────────────────────── STOMP ────────────────────────────

  Future<void> _connectStomp() async {
    final token = await widget.storage.getToken();
    _stomp.connect(
      authToken: token,
      onConnected: () {
        if (!mounted) return;
        setState(() => _stompConnected = true);
        // Re-subscribe if we already have an active conversation
        final conv = _activeConversation;
        if (conv != null && conv.conversationId > 0) {
          _subscribeStomp(conv.conversationId);
        }
      },
      onDisconnected: () {
        if (!mounted) return;
        setState(() {
          _stompConnected = false;
          _remoteTyping = false;
        });
      },
    );
  }

  void _subscribeStomp(int conversationId) {
    _stomp.subscribeConversation(
      conversationId,
      onMessage: (data) {
        if (!mounted) return;
        final msg = _messageFromMap(data);
        if (msg == null) return;
        setState(() {
          final current = _activeConversation;
          if (current == null || current.conversationId != conversationId) return;
          // deduplicate by id
          if (current.messages.any((m) => m.id == msg.id && msg.id != 0)) return;
          _activeConversation = ChatbotConversationDetail(
            conversationId: current.conversationId,
            status: current.status,
            lastIntent: current.lastIntent,
            lastConfidence: current.lastConfidence,
            startedAt: current.startedAt,
            escalatedAt: current.escalatedAt,
            messages: [...current.messages, msg],
          );
        });
        _scrollToBottom();
      },
      onStatus: (event) {
        if (!mounted) return;
        final newStatus = event['status'] as String?;
        setState(() {
          final current = _activeConversation;
          if (current == null || current.conversationId != conversationId) return;
          _activeConversation = ChatbotConversationDetail(
            conversationId: current.conversationId,
            status: newStatus ?? current.status,
            lastIntent: current.lastIntent,
            lastConfidence: current.lastConfidence,
            startedAt: current.startedAt,
            escalatedAt: event['escalatedAt'] as String? ?? current.escalatedAt,
            messages: current.messages,
          );
          // Also refresh summary list
          _conversations = _conversations.map((c) {
            if (c.id != conversationId) return c;
            return ChatbotConversationSummary(
              id: c.id,
              status: newStatus ?? c.status,
              startedAt: c.startedAt,
              lastMessagePreview: event['lastMessagePreview'] as String? ?? c.lastMessagePreview,
            );
          }).toList();
        });
      },
      onTyping: (event) {
        if (!mounted) return;
        final senderType = (event['senderType'] as String? ?? '').toUpperCase();
        final isTyping = event['typing'] as bool? ?? false;
        // Only show when admin is typing to user
        if (senderType != 'ADMIN') return;
        _remoteTypingTimeout?.cancel();
        setState(() => _remoteTyping = isTyping);
        if (isTyping) {
          _remoteTypingTimeout = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _remoteTyping = false);
          });
        }
      },
    );
  }

  ChatbotMessage? _messageFromMap(Map<String, dynamic> data) {
    try {
      return ChatbotMessage(
        id: (data['id'] as num?)?.toInt() ?? 0,
        senderType: data['senderType'] as String? ?? 'BOT',
        messageType: data['messageType'] as String? ?? 'TEXT',
        content: data['content'] as String? ?? '',
        createdAt: data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────── DATA ─────────────────────────────

  bool get _isPersistedConversation => (_activeConversation?.conversationId ?? 0) > 0;

  ChatbotConversationDetail _emptyConversation() => ChatbotConversationDetail(
        conversationId: 0,
        status: 'OPEN',
        lastIntent: null,
        lastConfidence: null,
        startedAt: DateTime.now().toIso8601String(),
        escalatedAt: null,
        messages: const [],
      );

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_chatbotApi.bootstrap(), _chatbotApi.conversations()]);
      if (!mounted) return;
      setState(() {
        _bootstrap = results[0] as ChatbotBootstrapResponse;
        _conversations = results[1] as List<ChatbotConversationSummary>;
        _resetLocalFlow(clearMessages: true);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetLocalFlow({bool clearMessages = false}) {
    _selectedCategory = null;
    _currentItems = const [];
    _faqPath.clear();
    _showResolutionActions = false;
    if (clearMessages) _activeConversation = null;
  }

  Future<void> _reloadConversations({int? selectConversationId}) async {
    final conversations = await _chatbotApi.conversations();
    ChatbotConversationDetail? selected = _activeConversation;
    final targetId = selectConversationId ?? (_isPersistedConversation ? _activeConversation?.conversationId : null);
    if (targetId != null) {
      try {
        selected = await _chatbotApi.conversation(targetId);
      } catch (_) {
        selected = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _activeConversation = selected;
    });
  }

  Future<void> _openCategory(ChatbotCategory category) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedCategory = category;
      _currentItems = const [];
      _faqPath.clear();
      _activeConversation = null;
      _showResolutionActions = false;
    });
    try {
      final items = await _chatbotApi.faqItems(categoryId: category.id);
      if (mounted) setState(() => _currentItems = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectFaq(ChatbotFaqItem item) async {
    final now = DateTime.now().toIso8601String();
    final current = _activeConversation ?? _emptyConversation();
    setState(() {
      _activeConversation = ChatbotConversationDetail(
        conversationId: 0,
        status: 'OPEN',
        lastIntent: item.categoryCode,
        lastConfidence: 100,
        startedAt: current.startedAt,
        escalatedAt: null,
        messages: [
          ...current.messages,
          ChatbotMessage(id: 0, senderType: 'USER', messageType: 'FAQ_SELECTION', content: item.question, createdAt: now),
          ChatbotMessage(id: 0, senderType: 'BOT', messageType: 'FAQ_MATCH', content: item.answer, createdAt: now),
        ],
      );
      _faqPath.add(item);
      _currentItems = const [];
      _showResolutionActions = false;
    });

    if (item.childCount <= 0) {
      setState(() => _showResolutionActions = true);
      _scrollToBottom();
      return;
    }

    setState(() => _loading = true);
    try {
      final children = await _chatbotApi.faqItems(parentFaqId: item.id);
      if (!mounted) return;
      setState(() {
        _currentItems = children;
        _showResolutionActions = children.isEmpty;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backInFaqTree() async {
    if (_faqPath.isEmpty) {
      setState(() => _resetLocalFlow(clearMessages: true));
      return;
    }
    _faqPath.removeLast();
    _showResolutionActions = false;
    if (_faqPath.isEmpty) {
      final category = _selectedCategory;
      if (category != null) await _openCategory(category);
      return;
    }
    setState(() => _loading = true);
    try {
      final children = await _chatbotApi.faqItems(parentFaqId: _faqPath.last.id);
      if (mounted) setState(() => _currentItems = children);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || _sending) return;
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inMilliseconds < 700) return;
    _lastSentAt = now;

    // Cancel any pending typing indicator
    _typingDebounce?.cancel();
    if (_isPersistedConversation) {
      _stomp.sendTyping(
        conversationId: _activeConversation!.conversationId,
        senderId: 0, // user id not needed for UI; server ignores for USER type
        typing: false,
      );
    }

    setState(() {
      _sending = true;
      _error = null;
      _showResolutionActions = false;
    });

    try {
      if (_isPersistedConversation) {
        // ── REALTIME PATH: send via STOMP, rely on subscription for echo ──
        // But also call REST so server persists & processes the message
        final convId = _activeConversation!.conversationId;
        await _chatbotApi.sendMessage(
          conversationId: convId,
          temporary: false,
          message: message,
        );
        _messageCtrl.clear();
        // The STOMP subscription will push the persisted message back
      } else {
        // ── TEMPORARY / BOT PATH: REST only ──
        final response = await _chatbotApi.sendMessage(
          conversationId: null,
          temporary: true,
          message: message,
        );
        _messageCtrl.clear();
        final current = _activeConversation ?? _emptyConversation();
        setState(() {
          _activeConversation = ChatbotConversationDetail(
            conversationId: 0,
            status: 'OPEN',
            lastIntent: response.matchedCategoryCode,
            lastConfidence: response.confidence,
            startedAt: current.startedAt,
            escalatedAt: null,
            messages: [...current.messages, response.userMessage, response.botMessage],
          );
          _currentItems = response.followUps;
          _showResolutionActions = response.followUps.isEmpty;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onTypingChanged(String value) {
    if (!_isPersistedConversation) return;
    _typingDebounce?.cancel();
    _stomp.sendTyping(
      conversationId: _activeConversation!.conversationId,
      senderId: 0,
      typing: value.isNotEmpty,
    );
    if (value.isNotEmpty) {
      // Auto-stop typing signal after 3s of no keystroke
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        if (_isPersistedConversation) {
          _stomp.sendTyping(
            conversationId: _activeConversation!.conversationId,
            senderId: 0,
            typing: false,
          );
        }
      });
    }
  }

  Future<void> _escalate() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      ChatbotConversationDetail detail;
      if (_isPersistedConversation) {
        detail = await _chatbotApi.escalate(_activeConversation!.conversationId);
      } else {
        final current = _activeConversation ?? _emptyConversation();
        final transcript = current.messages.isEmpty
            ? [
                ChatbotMessage(
                  id: 0,
                  senderType: 'USER',
                  messageType: 'TEXT',
                  content: 'Tôi cần gặp nhân viên CSKH',
                  createdAt: DateTime.now().toIso8601String(),
                )
              ]
            : current.messages;
        detail = await _chatbotApi.escalateTemporary(transcript);
      }
      if (!mounted) return;

      // Subscribe STOMP for this new persisted conversation
      _subscribeStomp(detail.conversationId);

      setState(() {
        _activeConversation = detail;
        _currentItems = const [];
        _showResolutionActions = false;
      });
      await _reloadConversations(selectConversationId: detail.conversationId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openConversation(int conversationId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _chatbotApi.conversation(conversationId);
      if (!mounted) return;

      // Switch STOMP subscription
      if (_activeConversation != null && _activeConversation!.conversationId > 0) {
        _stomp.unsubscribeConversation(_activeConversation!.conversationId);
      }
      _subscribeStomp(conversationId);

      setState(() {
        _activeConversation = detail;
        _resetLocalFlow();
        _tabController.index = 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startNewFlow() {
    if (_activeConversation != null && _activeConversation!.conversationId > 0) {
      _stomp.unsubscribeConversation(_activeConversation!.conversationId);
    }
    setState(() {
      _messageCtrl.clear();
      _resetLocalFlow(clearMessages: true);
    });
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!_messageScrollCtrl.hasClients) return;
      _messageScrollCtrl.animateTo(
        _messageScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ─────────────────────────── HELPERS ──────────────────────────

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING_AGENT':
        return 'Đang chờ CSKH';
      case 'IN_PROGRESS':
        return 'Đang được xử lý';
      case 'CLOSED':
        return 'Đã đóng';
      default:
        return 'Bot hỗ trợ';
    }
  }

  String _formatTime(String value) {
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  // ─────────────────────────── UI ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Trợ lý AI MiniBank'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.circle,
              size: 10,
              color: _stompConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chat hỗ trợ'), Tab(text: 'Các luồng chat')],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatTab(), _buildConversationList()],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat ngay'),
            )
          : null,
    );
  }

  Widget _buildChatTab() {
    final conversation = _activeConversation;
    final messages = conversation?.messages ?? const <ChatbotMessage>[];
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusLabel(conversation?.status ?? 'OPEN'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Intent: ${conversation?.lastIntent ?? '-'} | Confidence: ${conversation?.lastConfidence ?? 0}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _sending ? null : _escalate,
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Gặp CSKH'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _messageScrollCtrl,
                    padding: const EdgeInsets.all(12),
                    children: [
                      ...messages.map(_buildMessageBubble),
                      if (_remoteTyping) _buildTypingIndicator(),
                      if (messages.isEmpty && _selectedCategory == null) _buildCategoryList(),
                      if ((_selectedCategory != null || _currentItems.isNotEmpty) && !_showResolutionActions) _buildFaqList(),
                      if (_showResolutionActions) _buildResolutionActions(),
                    ],
                  ),
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            SizedBox(width: 4),
            _TypingDot(delay: 150),
            SizedBox(width: 4),
            _TypingDot(delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatbotMessage message) {
    final sender = message.senderType.toUpperCase();
    final isMine = sender == 'USER';
    final isAdmin = sender == 'ADMIN';
    final bg = isMine ? const Color(0xFF2563EB) : isAdmin ? const Color(0xFF0D9488) : const Color(0xFFF3F4F6);
    final fg = isMine || isAdmin ? Colors.white : const Color(0xFF111827);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: TextStyle(color: fg)),
            const SizedBox(height: 2),
            Text(_formatTime(message.createdAt), style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final categories = _bootstrap?.categories ?? const <ChatbotCategory>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xin chào! Bạn muốn được hỗ trợ nhóm vấn đề nào?', style: TextStyle(color: Color(0xFF374151))),
        const SizedBox(height: 12),
        const Text('Danh mục câu hỏi', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        ...categories.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: _sending ? null : () => _openCategory(item),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name, textAlign: TextAlign.left)),
                    Text('${item.faqCount}', style: const TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFaqList() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: _loading ? null : _backInFaqTree, icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: Text(
                  _faqPath.isEmpty ? (_selectedCategory?.name ?? 'Câu hỏi') : 'Câu hỏi tiếp theo',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
              ),
            ],
          ),
          if (_currentItems.isEmpty && !_loading && !_showResolutionActions)
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text('Nhánh này chưa có câu hỏi tiếp theo.', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ..._currentItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _sending || _loading ? null : () => _selectFaq(item),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.question, textAlign: TextAlign.left)),
                      if (item.childCount > 0) const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildResolutionActions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bạn đã đạt được mục đích chưa?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: _startNewFlow, child: const Text('Đã xong')),
              OutlinedButton(onPressed: _startNewFlow, child: const Text('Hỏi câu khác')),
              FilledButton(onPressed: _sending ? null : _escalate, child: const Text('Gặp CSKH')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              textInputAction: TextInputAction.send,
              onChanged: _onTypingChanged,
              onSubmitted: _sending ? null : _sendMessage,
              decoration: InputDecoration(
                hintText: 'Nhập câu hỏi của bạn...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _sending ? null : () => _sendMessage(_messageCtrl.text),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(52, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return RefreshIndicator(
      onRefresh: () async => _reloadConversations(),
      child: _conversations.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: const [SizedBox(height: 80), Center(child: Text('Chưa có luồng chat với CSKH.'))],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final item = _conversations[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: item.id == _activeConversation?.conversationId ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _openConversation(item.id),
                    title: Text('Luồng #${item.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${_statusLabel(item.status)}\n${item.lastMessagePreview ?? 'Chưa có nội dung'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(_formatTime(item.startedAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                );
              },
            ),
    );
  }
}

/// Animated typing dot widget
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle),
        ),
      ),
    );
  }
}