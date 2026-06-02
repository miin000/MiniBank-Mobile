import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

typedef OnMessageReceived = void Function(Map<String, dynamic> payload);
typedef OnConversationEvent = void Function(Map<String, dynamic> event);
typedef OnTypingEvent = void Function(Map<String, dynamic> event);
typedef OnConnected = void Function();
typedef OnDisconnected = void Function();

class StompChatClient {
  final String wsUrl;

  StompClient? _client;
  bool _connected = false;

  final Map<int, List<void Function()>> _subs = {};

  StompChatClient({required this.wsUrl});

  bool get isConnected => _connected;

  void connect({
    OnConnected? onConnected,
    OnDisconnected? onDisconnected,
    String? authToken,
  }) {
    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          _connected = true;
          onConnected?.call();
        },
        onDisconnect: (StompFrame frame) {
          _connected = false;
          _subs.clear();
          onDisconnected?.call();
        },
        onWebSocketError: (dynamic error) {
          _connected = false;
          onDisconnected?.call();
        },
        onStompError: (StompFrame frame) {
          _connected = false;
        },
        stompConnectHeaders:
            authToken != null ? {'Authorization': 'Bearer $authToken'} : {},
        webSocketConnectHeaders:
            authToken != null ? {'Authorization': 'Bearer $authToken'} : {},
        heartbeatOutgoing: const Duration(seconds: 20),
        heartbeatIncoming: const Duration(seconds: 20),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
  }

  void subscribeConversation(
    int conversationId, {
    required OnMessageReceived onMessage,
    OnConversationEvent? onStatus,
    OnTypingEvent? onTyping,
  }) {
    unsubscribeConversation(conversationId);

    if (!_connected || _client == null) return;

    final unsubs = <void Function()>[];

    final unsubMsg = _client!.subscribe(
      destination: '/topic/chat/$conversationId',
      callback: (StompFrame frame) {
        if (frame.body == null) return;

        try {
          final data = jsonDecode(frame.body!) as Map<String, dynamic>;
          onMessage(data);
        } catch (_) {}
      },
    );

    unsubs.add(() {
      unsubMsg();
    });

    if (onStatus != null) {
      final unsubStatus = _client!.subscribe(
        destination: '/topic/chat/$conversationId/status',
        callback: (StompFrame frame) {
          if (frame.body == null) return;

          try {
            final data = jsonDecode(frame.body!) as Map<String, dynamic>;
            onStatus(data);
          } catch (_) {}
        },
      );

      unsubs.add(() {
        unsubStatus();
      });
    }

    if (onTyping != null) {
      final unsubTyping = _client!.subscribe(
        destination: '/topic/chat/$conversationId/typing',
        callback: (StompFrame frame) {
          if (frame.body == null) return;

          try {
            final data = jsonDecode(frame.body!) as Map<String, dynamic>;
            onTyping(data);
          } catch (_) {}
        },
      );

      unsubs.add(() {
        unsubTyping();
      });
    }

    _subs[conversationId] = unsubs;
  }

  void unsubscribeConversation(int conversationId) {
    final list = _subs.remove(conversationId);

    if (list != null) {
      for (final unsub in list) {
        try {
          unsub();
        } catch (_) {}
      }
    }
  }

  void sendMessage({
    required int conversationId,
    required String content,
    required int senderId,
    String senderType = 'USER',
  }) {
    if (!_connected || _client == null) return;

    _client!.send(
      destination: '/app/chat.send',
      body: jsonEncode({
        'conversationId': conversationId,
        'senderId': senderId,
        'senderType': senderType,
        'content': content,
      }),
    );
  }

  void sendTyping({
    required int conversationId,
    required int senderId,
    required bool typing,
    String senderType = 'USER',
  }) {
    if (!_connected || _client == null) return;

    _client!.send(
      destination: '/app/chat.typing',
      body: jsonEncode({
        'conversationId': conversationId,
        'senderId': senderId,
        'senderType': senderType,
        'typing': typing,
      }),
    );
  }

  void disconnect() {
    for (final entry in _subs.values) {
      for (final unsub in entry) {
        try {
          unsub();
        } catch (_) {}
      }
    }

    _subs.clear();
    _client?.deactivate();
    _client = null;
    _connected = false;
  }
}