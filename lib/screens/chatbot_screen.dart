import 'dart:async';

import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/chatbot_api.dart';
import '../auth/auth_storage.dart';
import 'stomp_chat_client.dart';

// ─────────────────────────── THEME ────────────────────────────

class _ChatTheme {
  static const brandPurple = Color(0xFF4F3DCC);
  static const brandPurpleLight = Color(0xFF6B5CE7);
  static const brandPurpleSurface = Color(0xFFEDE9FE);
  static const agentTeal = Color(0xFF059669);
  static const agentTealSurface = Color(0xFFECFDF5);
  static const agentTealBorder = Color(0xFF6EE7B7);
  static const userBg = Color(0xFF4F3DCC);
  static const adminBg = Color(0xFF059669);
  static const surface = Color(0xFFF8F9FB);
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);
  static const inputBg = Color(0xFFF3F4F6);
  static const faqChipBorder = Color(0xFFD1D5DB);
  static const successGreen = Color(0xFF065F46);
}

// ─────────────────────────── WIDGET ───────────────────────────

class ChatbotScreen extends StatefulWidget {
  final String baseUrl;
  final String wsUrl;
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

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  late final ChatbotApi _chatbotApi;
  late final StompChatClient _stomp;
  late final TabController _tabController;

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _messageScrollCtrl = ScrollController();

  Timer? _typingDebounce;
  bool _remoteTyping = false;
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
  bool _showConnectedBanner = false;
  String? _connectedAgentName;
  String? _error;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _chatbotApi =
        ChatbotApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _stomp = StompChatClient(wsUrl: widget.wsUrl);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
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
        final currentStatus = (_activeConversation?.status ?? '').toUpperCase();
        final connectedNow = newStatus == 'IN_PROGRESS' && currentStatus != 'IN_PROGRESS';
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
          _conversations = _conversations.map((c) {
            if (c.id != conversationId) return c;
            return ChatbotConversationSummary(
              id: c.id,
              status: newStatus ?? c.status,
              startedAt: c.startedAt,
              lastMessagePreview:
                  event['lastMessagePreview'] as String? ?? c.lastMessagePreview,
            );
          }).toList();
          if (connectedNow) {
            _showAgentConnectedBanner(
              agentName: event['assignedAdminUsername'] as String?,
            );
          }
        });
      },
      onTyping: (event) {
        if (!mounted) return;
        final senderType = (event['senderType'] as String? ?? '').toUpperCase();
        final isTyping = event['typing'] as bool? ?? false;
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

  bool get _isConnectedToAgent =>
      (_activeConversation?.status ?? '').toUpperCase() == 'IN_PROGRESS';

  bool get _isWaitingForAgent =>
      (_activeConversation?.status ?? '').toUpperCase() == 'WAITING_AGENT';

  bool get _isEscalatedToSupport => _isConnectedToAgent || _isWaitingForAgent;

  void _showAgentConnectedBanner({String? agentName}) {
    _showConnectedBanner = true;
    _connectedAgentName = agentName ?? 'Nhân viên CSKH';
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showConnectedBanner = false);
    });
  }

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
      final results =
          await Future.wait([_chatbotApi.bootstrap(), _chatbotApi.conversations()]);
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
    _showConnectedBanner = false;
    if (clearMessages) _activeConversation = null;
  }

  Future<void> _reloadConversations({int? selectConversationId}) async {
    final conversations = await _chatbotApi.conversations();
    ChatbotConversationDetail? selected = _activeConversation;
    final targetId = selectConversationId ??
        (_isPersistedConversation ? _activeConversation?.conversationId : null);
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
          ChatbotMessage(
              id: 0,
              senderType: 'USER',
              messageType: 'FAQ_SELECTION',
              content: item.question,
              createdAt: now),
          ChatbotMessage(
              id: 0,
              senderType: 'BOT',
              messageType: 'FAQ_MATCH',
              content: item.answer,
              createdAt: now),
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

    _typingDebounce?.cancel();
    if (_isPersistedConversation) {
      _stomp.sendTyping(
        conversationId: _activeConversation!.conversationId,
        senderId: 0,
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
        final convId = _activeConversation!.conversationId;
        await _chatbotApi.sendMessage(
          conversationId: convId,
          temporary: false,
          message: message,
        );
        _messageCtrl.clear();
      } else {
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
      _subscribeStomp(detail.conversationId);
      setState(() {
        _activeConversation = detail;
        _currentItems = const [];
        _showResolutionActions = false;
        if (detail.status.toUpperCase() == 'IN_PROGRESS') {
          _showAgentConnectedBanner();
        }
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
      if (_activeConversation != null && _activeConversation!.conversationId > 0) {
        _stomp.unsubscribeConversation(_activeConversation!.conversationId);
      }
      _subscribeStomp(conversationId);
      setState(() {
        _activeConversation = detail;
        _resetLocalFlow();
        _tabController.index = 0;
        if (detail.status.toUpperCase() == 'IN_PROGRESS') {
          _showAgentConnectedBanner();
        }
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING_AGENT':
        return const Color(0xFFD97706);
      case 'IN_PROGRESS':
        return _ChatTheme.agentTeal;
      case 'CLOSED':
        return _ChatTheme.textHint;
      default:
        return _ChatTheme.brandPurple;
    }
  }

  String _formatTime(String value) {
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  // ─────────────────────────── UI ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ChatTheme.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_error != null) _buildErrorBanner(),
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
              backgroundColor: _ChatTheme.brandPurple,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat ngay',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _ChatTheme.brandPurple,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trợ lý AI MiniBank',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('Luôn sẵn sàng hỗ trợ',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stompConnected
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFB923C),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _stompConnected ? 'Trực tuyến' : 'Đang kết nối',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Chat hỗ trợ'),
          Tab(text: 'Lịch sử chat'),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFB91C1C), fontSize: 12.5)),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFFDC2626), size: 16),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── CHAT TAB ─────────────────────────

  Widget _buildChatTab() {
    final conversation = _activeConversation;
    final messages = conversation?.messages ?? const <ChatbotMessage>[];
    final status = conversation?.status ?? 'OPEN';

    return Column(
      children: [
        _buildStatusBar(status, conversation),
        if (_showConnectedBanner) _buildConnectedBanner(),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            decoration: BoxDecoration(
              color: _ChatTheme.surface,
              borderRadius: BorderRadius.circular(0),
            ),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _ChatTheme.brandPurple))
                : ListView(
                    controller: _messageScrollCtrl,
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    children: [
                      ...messages.map(_buildMessageBubble),
                      if (_remoteTyping) _buildTypingIndicator(),
                      if (messages.isEmpty && _selectedCategory == null)
                        _buildCategoryList(),
                      if ((_selectedCategory != null ||
                              _currentItems.isNotEmpty) &&
                          !_showResolutionActions)
                        _buildFaqList(),
                      if (_showResolutionActions) _buildResolutionActions(),
                    ],
                  ),
          ),
        ),
        _buildInputBar(status),
      ],
    );
  }

  Widget _buildStatusBar(String status, ChatbotConversationDetail? conversation) {
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ChatTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabel(status),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color)),
                if (conversation?.lastIntent != null)
                  Text(
                    'Intent: ${conversation!.lastIntent} · ${conversation.lastConfidence ?? 0}%',
                    style: const TextStyle(
                        fontSize: 11, color: _ChatTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (!_isEscalatedToSupport)
            GestureDetector(
              onTap: _sending ? null : _escalate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: _ChatTheme.brandPurple),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headset_mic_rounded,
                        size: 14, color: _ChatTheme.brandPurple),
                    const SizedBox(width: 5),
                    Text('Gặp CSKH',
                        style: TextStyle(
                            fontSize: 12,
                            color: _ChatTheme.brandPurple,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectedBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _ChatTheme.agentTealSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ChatTheme.agentTealBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: _ChatTheme.agentTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đã kết nối thành công với nhân viên CSKH!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _ChatTheme.successGreen)),
                if (_connectedAgentName != null)
                  Text(
                    '$_connectedAgentName sẽ hỗ trợ bạn ngay bây giờ.',
                    style: const TextStyle(
                        fontSize: 12, color: _ChatTheme.agentTeal),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: _ChatTheme.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                SizedBox(width: 5),
                _TypingDot(delay: 150),
                SizedBox(width: 5),
                _TypingDot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ChatTheme.brandPurple, _ChatTheme.brandPurpleLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
    );
  }

  Widget _buildMessageBubble(ChatbotMessage message) {
    final sender = message.senderType.toUpperCase();
    final isMine = sender == 'USER';
    final isAdmin = sender == 'ADMIN';

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: const BoxDecoration(
                  color: _ChatTheme.userBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(message.content,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(_formatTime(message.createdAt),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _ChatTheme.brandPurpleSurface,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.person_rounded,
                  size: 16, color: _ChatTheme.brandPurple),
            ),
          ],
        ),
      );
    }

    // Bot or Admin bubble
    final bubbleBg = isAdmin ? _ChatTheme.adminBg : Colors.white;
    final textColor = isAdmin ? Colors.white : _ChatTheme.textPrimary;
    final timeColor =
        isAdmin ? Colors.white60 : _ChatTheme.textHint;
    final borderColor = isAdmin ? Colors.transparent : _ChatTheme.border;
    final borderLeft =
        isAdmin ? const Radius.circular(4) : const Radius.circular(4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAdmin)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _ChatTheme.agentTealSurface,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  size: 16, color: _ChatTheme.agentTeal),
            )
          else
            _buildBotAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                  bottomLeft: borderLeft,
                ),
                border: Border.all(color: borderColor),
                boxShadow: isAdmin
                    ? null
                    : [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Nhân viên CSKH',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  Text(message.content,
                      style: TextStyle(color: textColor, fontSize: 14, height: 1.45)),
                  const SizedBox(height: 3),
                  Text(_formatTime(message.createdAt),
                      style: TextStyle(color: timeColor, fontSize: 10.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    final categories = _bootstrap?.categories ?? const <ChatbotCategory>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Xin chào! Bạn muốn được hỗ trợ về chủ đề nào?',
          style: TextStyle(
              color: _ChatTheme.textSecondary,
              fontSize: 13.5,
              height: 1.4),
        ),
        const SizedBox(height: 14),
        const Text('Danh mục câu hỏi',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _ChatTheme.textPrimary)),
        const SizedBox(height: 10),
        ...categories.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: _sending ? null : () => _openCategory(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ChatTheme.faqChipBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: _ChatTheme.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _ChatTheme.brandPurpleSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${item.faqCount}',
                            style: const TextStyle(
                                color: _ChatTheme.brandPurple,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: _ChatTheme.textSecondary),
                    ],
                  ),
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
              GestureDetector(
                onTap: _loading ? null : _backInFaqTree,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _ChatTheme.border),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: _ChatTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _faqPath.isEmpty
                      ? (_selectedCategory?.name ?? 'Câu hỏi')
                      : 'Câu hỏi tiếp theo',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _ChatTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_currentItems.isEmpty && !_loading && !_showResolutionActions)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Nhánh này chưa có câu hỏi tiếp theo.',
                  style: TextStyle(
                      color: _ChatTheme.textSecondary, fontSize: 13)),
            ),
          ..._currentItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: (_sending || _loading) ? null : () => _selectFaq(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _ChatTheme.faqChipBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.question,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: _ChatTheme.textPrimary)),
                        ),
                        if (item.childCount > 0)
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: _ChatTheme.textSecondary),
                      ],
                    ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ChatTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bạn đã được hỗ trợ chưa?',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: _ChatTheme.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _resolutionBtn(
                  label: '✓ Đã xong',
                  onTap: _startNewFlow,
                  filled: false,
                  color: _ChatTheme.agentTeal),
              _resolutionBtn(
                  label: 'Hỏi câu khác',
                  onTap: _startNewFlow,
                  filled: false,
                  color: _ChatTheme.textSecondary),
              _resolutionBtn(
                  label: 'Gặp CSKH',
                  onTap: _sending ? null : _escalate,
                  filled: true,
                  color: _ChatTheme.brandPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resolutionBtn({
    required String label,
    required VoidCallback? onTap,
    required bool filled,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color)),
      ),
    );
  }

  Widget _buildInputBar(String status) {
    final isEscalated = _isEscalatedToSupport;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _ChatTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _ChatTheme.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _ChatTheme.border),
              ),
              child: TextField(
                controller: _messageCtrl,
                textInputAction: TextInputAction.send,
                onChanged: _onTypingChanged,
                onSubmitted: _sending ? null : _sendMessage,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isEscalated
                      ? 'Nhắn tin với nhân viên CSKH...'
                      : 'Nhập câu hỏi của bạn...',
                  hintStyle: const TextStyle(
                      color: _ChatTheme.textHint, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : () => _sendMessage(_messageCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _sending
                    ? _ChatTheme.brandPurple.withValues(alpha: 0.6)
                    : _ChatTheme.brandPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send_rounded,
                      size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── CONV LIST ────────────────────────

  Widget _buildConversationList() {
    return RefreshIndicator(
      color: _ChatTheme.brandPurple,
      onRefresh: () async => _reloadConversations(),
      child: _conversations.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: _ChatTheme.textHint.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text('Chưa có lịch sử chat với CSKH.',
                          style: TextStyle(
                              color: _ChatTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final item = _conversations[index];
                final isActive = item.id == _activeConversation?.conversationId;
                return GestureDetector(
                  onTap: () => _openConversation(item.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _ChatTheme.brandPurpleSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isActive
                              ? _ChatTheme.brandPurple.withValues(alpha: 0.4)
                              : _ChatTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(item.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.chat_rounded,
                              size: 20,
                              color: _statusColor(item.status)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Luồng #${item.id}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(item.status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(_statusLabel(item.status),
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(item.status))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.lastMessagePreview ?? 'Chưa có nội dung',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _ChatTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatTime(item.startedAt),
                            style: const TextStyle(
                                fontSize: 11,
                                color: _ChatTheme.textHint)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────── TYPING DOT ───────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          decoration: const BoxDecoration(
              color: _ChatTheme.textHint, shape: BoxShape.circle),
        ),
      ),
    );
  }
}