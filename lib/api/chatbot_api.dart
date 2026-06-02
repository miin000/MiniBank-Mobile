import 'authed_api.dart';

class ChatbotCategory {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int faqCount;

  ChatbotCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.faqCount,
  });

  factory ChatbotCategory.fromJson(Map<String, dynamic> json) {
    return ChatbotCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      faqCount: (json['faqCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatbotFaqItem {
  final int id;
  final int categoryId;
  final String categoryName;
  final String categoryCode;
  final int? parentFaqId;
  final String question;
  final String answer;
  final int childCount;
  final List<String> keywords;
  final bool active;

  ChatbotFaqItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryCode,
    required this.parentFaqId,
    required this.question,
    required this.answer,
    required this.childCount,
    required this.keywords,
    required this.active,
  });

  factory ChatbotFaqItem.fromJson(Map<String, dynamic> json) {
    return ChatbotFaqItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName']?.toString() ?? '',
      categoryCode: json['categoryCode']?.toString() ?? '',
      parentFaqId: (json['parentFaqId'] as num?)?.toInt(),
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      childCount: (json['childCount'] as num?)?.toInt() ?? 0,
      keywords: (json['keywords'] as List?)?.map((item) => item.toString()).toList() ?? const [],
      active: json['active'] == true,
    );
  }
}

class ChatbotMessage {
  final int id;
  final String senderType;
  final String messageType;
  final String content;
  final String createdAt;

  ChatbotMessage({
    required this.id,
    required this.senderType,
    required this.messageType,
    required this.content,
    required this.createdAt,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderType: json['senderType']?.toString() ?? 'BOT',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toTranscriptJson() {
    return {
      'senderType': senderType,
      'messageType': messageType,
      'content': content,
    };
  }
}

class ChatbotConversationSummary {
  final int id;
  final String status;
  final String? lastIntent;
  final int? lastConfidence;
  final String startedAt;
  final String? escalatedAt;
  final String? lastMessagePreview;

  ChatbotConversationSummary({
    required this.id,
    required this.status,
    this.lastIntent,
    this.lastConfidence,
    required this.startedAt,
    this.escalatedAt,
    this.lastMessagePreview,
  });

  factory ChatbotConversationSummary.fromJson(Map<String, dynamic> json) {
    return ChatbotConversationSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      lastIntent: json['lastIntent']?.toString(),
      lastConfidence: (json['lastConfidence'] as num?)?.toInt(),
      startedAt: json['startedAt']?.toString() ?? '',
      escalatedAt: json['escalatedAt']?.toString(),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
    );
  }
}

class ChatbotConversationDetail {
  final int conversationId;
  final String status;
  final String? lastIntent;
  final int? lastConfidence;
  final String startedAt;
  final String? escalatedAt;
  final List<ChatbotMessage> messages;

  ChatbotConversationDetail({
    required this.conversationId,
    required this.status,
    this.lastIntent,
    this.lastConfidence,
    required this.startedAt,
    this.escalatedAt,
    required this.messages,
  });

  factory ChatbotConversationDetail.fromJson(Map<String, dynamic> json) {
    return ChatbotConversationDetail(
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      lastIntent: json['lastIntent']?.toString(),
      lastConfidence: (json['lastConfidence'] as num?)?.toInt(),
      startedAt: json['startedAt']?.toString() ?? '',
      escalatedAt: json['escalatedAt']?.toString(),
      messages: (json['messages'] as List?)
              ?.map((item) => ChatbotMessage.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ChatbotBootstrapResponse {
  final List<ChatbotCategory> categories;
  final List<ChatbotFaqItem> suggestedQuestions;

  ChatbotBootstrapResponse({
    required this.categories,
    required this.suggestedQuestions,
  });

  factory ChatbotBootstrapResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotBootstrapResponse(
      categories: (json['categories'] as List?)
              ?.map((item) => ChatbotCategory.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      suggestedQuestions: (json['suggestedQuestions'] as List?)
              ?.map((item) => ChatbotFaqItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ChatbotSendResponse {
  final int conversationId;
  final ChatbotMessage userMessage;
  final ChatbotMessage botMessage;
  final int? matchedFaqId;
  final String? matchedCategoryCode;
  final int? confidence;
  final List<ChatbotFaqItem> followUps;
  final bool escalated;

  ChatbotSendResponse({
    required this.conversationId,
    required this.userMessage,
    required this.botMessage,
    required this.matchedFaqId,
    required this.matchedCategoryCode,
    required this.confidence,
    required this.followUps,
    required this.escalated,
  });

  factory ChatbotSendResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotSendResponse(
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      userMessage: ChatbotMessage.fromJson(json['userMessage'] as Map<String, dynamic>? ?? {}),
      botMessage: ChatbotMessage.fromJson(json['botMessage'] as Map<String, dynamic>? ?? {}),
      matchedFaqId: (json['matchedFaqId'] as num?)?.toInt(),
      matchedCategoryCode: json['matchedCategoryCode']?.toString(),
      confidence: (json['confidence'] as num?)?.toInt(),
      followUps: (json['followUps'] as List?)
              ?.map((item) => ChatbotFaqItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      escalated: json['escalated'] == true,
    );
  }
}

class ChatbotApi {
  final AuthedApi api;

  ChatbotApi({required this.api});

  Future<ChatbotBootstrapResponse> bootstrap() async {
    return api.getJson<ChatbotBootstrapResponse>(
      '/api/mobile/chatbot/bootstrap',
      parser: (decoded) {
        if (decoded == null) {
          return ChatbotBootstrapResponse(categories: const [], suggestedQuestions: const []);
        }
        return ChatbotBootstrapResponse.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<List<ChatbotConversationSummary>> conversations() async {
    final list = await api.getJson<List>(
      '/api/mobile/chatbot/conversations',
      parser: (decoded) {
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list.map((item) => ChatbotConversationSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatbotConversationDetail> conversation(int conversationId) async {
    return api.getJson<ChatbotConversationDetail>(
      '/api/mobile/chatbot/conversations/$conversationId',
      parser: (decoded) {
        if (decoded == null) throw Exception('Conversation not found');
        return ChatbotConversationDetail.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<List<ChatbotFaqItem>> faqItems({int? categoryId, int? parentFaqId}) async {
    final params = <String>[];
    if (categoryId != null) params.add('categoryId=$categoryId');
    if (parentFaqId != null) params.add('parentFaqId=$parentFaqId');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final list = await api.getJson<List>(
      '/api/mobile/chatbot/faq/items$query',
      parser: (decoded) {
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list.map((item) => ChatbotFaqItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatbotSendResponse> sendMessage({int? conversationId, required String message, bool temporary = false}) async {
    return api.postJson<ChatbotSendResponse>(
      '/api/mobile/chatbot/messages',
      body: {
        if (conversationId != null) 'conversationId': conversationId,
        if (temporary) 'temporary': true,
        'message': message,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Send message failed');
        return ChatbotSendResponse.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<ChatbotConversationDetail> escalate(int conversationId) async {
    return api.postJson<ChatbotConversationDetail>(
      '/api/mobile/chatbot/conversations/$conversationId/escalate',
      body: {},
      parser: (decoded) {
        if (decoded == null) throw Exception('Escalation failed');
        return ChatbotConversationDetail.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<ChatbotConversationDetail> escalateTemporary(List<ChatbotMessage> messages) async {
    return api.postJson<ChatbotConversationDetail>(
      '/api/mobile/chatbot/conversations/escalate',
      body: {
        'messages': messages.map((item) => item.toTranscriptJson()).toList(),
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Escalation failed');
        return ChatbotConversationDetail.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }
}
