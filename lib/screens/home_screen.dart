import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../api/account_api.dart';
import '../api/authed_api.dart';
import '../api/expense_api.dart';
import '../api/profile_api.dart';
import '../api/transaction_api.dart';
import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../auth/auth_models.dart';
import '../security/device_identity.dart';
import 'account_setup_screen.dart';
import 'login_screen.dart';
import 'kyc_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'qr_screen.dart';
import 'services_screen.dart';
import 'create_loan_screen.dart';
import 'create_saving_screen.dart';
import 'transfer_screen.dart';
import 'transaction_history_screen.dart';
import 'notification_screen.dart';
import '../utils/url_utils.dart';

class HomeScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const HomeScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  AuthUser? _user;
  int _navIndex = 0;
  AccountSummary? _summary;
  List<TransactionSummary> _recent = const [];
  DailyRecommendation? _aiRecommendation;
  bool _loadingSummary = false;
  bool _loadingRecent = false;
  bool _loadingProfile = false;
  bool _loadingAiRecommendation = false;
  bool _hideBalance = true;
  String? _summaryError;
  String? _recentError;
  String? _aiRecommendationError;
  String? _profileStatus;
  int _profileAccountCount = 0;
  late AnimationController _balanceAnimCtrl;
  late Animation<double> _balanceFade;

  static const _primaryBlue = Color(0xFF1B4FD8);
  static const _surfaceBlue = Color(0xFFEEF2FF);

  @override
  void initState() {
    super.initState();
    _balanceAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _balanceFade = CurvedAnimation(parent: _balanceAnimCtrl, curve: Curves.easeOut);
    widget.storage.getUser().then((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
    Future.wait([
      _loadSummary(),
      _loadRecent(),
      _loadProfile(),
      _loadAiRecommendation(),
    ]);
  }

  @override
  void dispose() {
    _balanceAnimCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  String _displayName() {
    final user = _user;
    if (user == null) return 'bạn';
    return user.phone ?? user.username ?? 'bạn';
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature đang phát triển'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openTransfer() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TransferScreen(
        baseUrl: widget.baseUrl,
        storage: widget.storage,
        identity: widget.identity,
      )),
    );
    if (completed == true) {
      await _loadSummary();
      await _loadRecent();
    }
  }

  Future<void> _openQr() async {
    final needsReload = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(builder: (_) => QrScreen(
        baseUrl: widget.baseUrl,
        storage: widget.storage,
        identity: widget.identity,
      )),
    );
    if (needsReload == true && mounted) {
      await _loadSummary();
      await _loadRecent();
    }
  }

  void _openKyc() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KycScreen(baseUrl: widget.baseUrl, storage: widget.storage)));

  void _openProfile() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(
          baseUrl: widget.baseUrl, storage: widget.storage, identity: widget.identity)));

  void _openServices() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServicesScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );

  Future<void> _openLoanApplication() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateLoanScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );

    if (submitted == true && mounted) {
      await _loadSummary();
      await _loadRecent();
      await _loadProfile();
    }
  }

  Future<void> _openSaving() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSavingScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );

    if (submitted == true && mounted) {
      await _loadSummary();
      await _loadRecent();
      await _loadProfile();
    }
  }

    void _openChatbot() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatbotScreen(
        baseUrl: widget.baseUrl,
        wsUrl: toWsUrl(widget.baseUrl),
        storage: widget.storage

        )));

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationScreen(baseUrl: widget.baseUrl, storage: widget.storage),
      ),
    );
  }

  void _openAccountSetup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountSetupScreen(
          baseUrl: widget.baseUrl, storage: widget.storage)),
    );
    if (created == true) {
      await _loadSummary();
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final profile = await api.me();
      if (!mounted) return;
      setState(() {
        _profileStatus = profile.status;
        _profileAccountCount = profile.accounts.length;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() { _loadingSummary = true; _summaryError = null; });
    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final summary = await api.summary();
      if (!mounted) return;
      setState(() => _summary = summary);
      _balanceAnimCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('No account is assigned')) {
        final status = (_profileStatus ?? '').toLowerCase();
        setState(() => _summaryError = status == 'active'
            ? 'Bạn đã được duyệt KYC. Hãy tạo số tài khoản để sử dụng dịch vụ.'
            : 'Bạn chưa có tài khoản. Hãy hoàn tất KYC và chờ admin duyệt.');
      } else {
        setState(() => _summaryError = msg);
      }
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadRecent() async {
    setState(() { _loadingRecent = true; _recentError = null; });
    try {
      final api = TransactionApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final recent = await api.recent(limit: 5);
      if (!mounted) return;
      setState(() => _recent = recent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recentError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _loadAiRecommendation() async {
    setState(() {
      _loadingAiRecommendation = true;
      _aiRecommendationError = null;
    });
    try {
      final authedApi = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final api = ExpenseApi(api: authedApi);
      final recommendation = await api.getDailyRecommendation();
      if (!mounted) return;
      setState(() => _aiRecommendation = recommendation);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiRecommendationError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAiRecommendation = false);
    }
  }

  String _rankLabel(String? rank) {
    if (rank == null || rank.isEmpty) return 'Chưa xếp hạng';
    return switch (rank.toLowerCase()) {
      'vip' => '★ VIP',
      'vang' => '● Vàng',
      'bac' => '● Bạc',
      'dong' => '● Đồng',
      _ => rank,
    };
  }

  Color _rankColor(String? rank) {
    return switch ((rank ?? '').toLowerCase()) {
      'vip' => const Color(0xFF7C3AED),
      'vang' => const Color(0xFFD97706),
      'bac' => const Color(0xFF6B7280),
      _ => const Color(0xFFB45309),
    };
  }

  String _formatAmount(String raw) {
    final num = double.tryParse(raw);
    if (num == null) return raw;
    final parts = num.toStringAsFixed(0).split('');
    final result = <String>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.add('.');
      result.add(parts[i]);
    }
    return result.join();
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _recommendationColor(String priority) {
    return switch (priority.toUpperCase()) {
      'HIGH' => const Color(0xFFDC2626),
      'MEDIUM' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
  }

  String _recommendationSourceLabel(String source) {
    return source == 'RULE_BASED_AND_GEMINI' ? 'Gemini AI' : 'Quy tắc thông minh';
  }

  Widget _buildAiAdvisorCard() {
    final recommendation = _aiRecommendation;
    final firstItem = recommendation?.recommendations.isNotEmpty == true
        ? recommendation!.recommendations.first
        : null;
    final accent = firstItem == null
        ? const Color(0xFF7C3AED)
        : _recommendationColor(firstItem.priority);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: recommendation == null ? _loadAiRecommendation : _showAiRecommendationsSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.09), const Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
              child: _loadingAiRecommendation
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    )
                  : Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Cố vấn chi tiêu AI',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  ),
                  if (recommendation != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        _recommendationSourceLabel(recommendation.source),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(
                  _loadingAiRecommendation
                      ? 'Đang phân tích chi tiêu của bạn...'
                      : _aiRecommendationError != null
                          ? 'Không tải được đề xuất. Nhấn để thử lại.'
                          : firstItem?.message ?? 'Chưa có đề xuất chi tiêu mới.',
                  style: TextStyle(fontSize: 12, color: accent.withOpacity(0.82), height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (recommendation != null) ...[
                  const SizedBox(height: 8),
                  Text('Điểm tiết kiệm: ${recommendation.savingScore}/100 • Rủi ro: ${recommendation.riskLevel}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            Icon(Icons.chevron_right, color: accent, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showAiRecommendationsSheet() async {
    final recommendation = _aiRecommendation;
    if (recommendation == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Đề xuất chi tiêu ${recommendation.month}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text('${_recommendationSourceLabel(recommendation.source)} • Điểm tiết kiệm ${recommendation.savingScore}/100',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 14),
            ...recommendation.recommendations.map((item) {
              final color = _recommendationColor(item.priority);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.16)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.tips_and_updates_rounded, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(height: 4),
                    Text(item.message, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.35)),
                  ])),
                ]),
              );
            }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final isActive = (_profileStatus ?? '').toLowerCase() == 'active';
    final hasAccount = summary != null || _profileAccountCount > 0;
    final rank = summary?.customerRank;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        const SizedBox(height: 2),
                        Text(_displayName(),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      ],
                    ),
                  ),
                  if (rank != null && rank.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _rankColor(rank).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _rankColor(rank).withOpacity(0.3)),
                      ),
                      child: Text(_rankLabel(rank),
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: _rankColor(rank))),
                    ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: _openNotifications,
                    color: const Color(0xFF374151),
                  ),
                  IconButton(
                    icon: const Icon(Icons.smart_toy_outlined),
                    tooltip: 'Chatbot',
                    onPressed: _openChatbot,
                    color: const Color(0xFF1B4FD8),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await widget.storage.clear();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => LoginScreen(
                            baseUrl: widget.baseUrl, api: widget.api,
                            storage: widget.storage, identity: widget.identity)),
                        (r) => false,
                      );
                    },
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEEF2FF),
                      child: Icon(Icons.person, size: 18, color: Color(0xFF1B4FD8)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([_loadSummary(), _loadRecent(), _loadProfile(), _loadAiRecommendation()]);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // ── Balance Card ──────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B4FD8), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1B4FD8).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // decorative circles
                          Positioned(
                            right: -20, top: -20,
                            child: Container(
                              width: 120, height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 30, bottom: -30,
                            child: Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Số dư khả dụng',
                                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    GestureDetector(
                                      onTap: summary == null ? null : () => setState(() => _hideBalance = !_hideBalance),
                                      child: Icon(
                                        _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: Colors.white70, size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _loadingSummary
                                    ? const SizedBox(
                                        height: 38,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: SizedBox(width: 24, height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                                        ),
                                      )
                                    : FadeTransition(
                                        opacity: _balanceFade,
                                        child: Text(
                                          summary == null
                                              ? '––'
                                              : _hideBalance
                                                  ? '••••••••'
                                                  : '${_formatAmount(summary.availableBalance.toString())} VND',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.credit_card_rounded, color: Colors.white54, size: 15),
                                    const SizedBox(width: 6),
                                    Text(
                                      summary == null ? '––' : summary.accountNumber,
                                      style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: summary == null ? null : () async {
                                        await Clipboard.setData(ClipboardData(text: summary.accountNumber));
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: const Text('Đã sao chép số tài khoản'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          margin: const EdgeInsets.all(16),
                                        ));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.copy_rounded, size: 13, color: Colors.white70),
                                            SizedBox(width: 4),
                                            Text('Sao chép', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (_summaryError != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.white70, size: 15),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_summaryError!,
                                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (isActive && !hasAccount) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _loadingProfile ? null : _openAccountSetup,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white54),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Tạo số tài khoản'),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: summary == null ? null : _openQr,
                                    icon: const Icon(Icons.qr_code_rounded, size: 16, color: Colors.white),
                                    label: const Text('Hiển thị QR nhận tiền',
                                        style: TextStyle(color: Colors.white, fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white30),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Transaction Limits ────────────────────────────────
                    if (summary != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _limitCard(
                                label: 'Hạn mức chuyển',
                                value: _formatAmount(summary.dailyTransferLimit?.toString() ?? '0'),
                                icon: Icons.trending_up_rounded,
                                color: const Color(0xFFFFF7ED),
                                iconColor: const Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _limitCard(
                                label: 'Hạn mức nhận',
                                value: _formatAmount(summary.dailyReceiveLimit?.toString() ?? '0'),
                                icon: Icons.trending_down_rounded,
                                color: const Color(0xFFF0FDF4),
                                iconColor: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Quick Actions ─────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _quickAction(
                            icon: Icons.send_rounded,
                            label: 'Chuyển tiền',
                            color: _primaryBlue,
                            onTap: _openTransfer,
                          ),
                          _quickAction(
                            icon: Icons.savings_rounded,
                            label: 'Tiết kiệm',
                            color: const Color(0xFF7C3AED),
                            onTap: _openSaving,
                          ),
                          _quickAction(
                            icon: Icons.account_balance_rounded,
                            label: 'Vay vốn',
                            color: const Color(0xFFEA580C),
                            onTap: _openLoanApplication,
                          ),
                          _quickAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'Lịch sử',
                            color: const Color(0xFF0D9488),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => TransactionHistoryScreen(
                                    baseUrl: widget.baseUrl, storage: widget.storage))),
                          ),
                        ],
                      ),
                    ),

                    // ── AI Advisor Banner ─────────────────────────────────
                    _buildAiAdvisorCard(),

                    // ── Recent Transactions ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Giao dịch gần đây',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => TransactionHistoryScreen(
                                    baseUrl: widget.baseUrl, storage: widget.storage))),
                            style: TextButton.styleFrom(foregroundColor: _primaryBlue),
                            child: const Text('Xem tất cả', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: _buildRecentTransactions(),
                    ),

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: _openProfile,
                        icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                        label: const Text('Hồ sơ / Bảo mật / Cài đặt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _navIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: _primaryBlue,
            unselectedItemColor: const Color(0xFF9CA3AF),
            selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            onTap: (index) async {
              if (index == 0) { setState(() => _navIndex = 0); return; }
              if (index == 1) {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TransactionHistoryScreen(
                        baseUrl: widget.baseUrl, storage: widget.storage)));
              }
              if (index == 2) { await _openQr(); }
              if (index == 3) {
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServicesScreen(
                      baseUrl: widget.baseUrl,
                      storage: widget.storage,
                      identity: widget.identity,
                    ),
                  ),
                );
              }
              if (index == 4) {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                        baseUrl: widget.baseUrl, storage: widget.storage, identity: widget.identity)));
              }
              if (mounted) setState(() => _navIndex = 0);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
              BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Lịch sử'),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner_rounded, size: 28),
                label: 'Quét QR',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.apps_rounded), label: 'Tiện ích'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Cá nhân'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _limitCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: iconColor.withOpacity(0.8))),
                const SizedBox(height: 2),
                Text('$value VND/ngày',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_loadingRecent) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_recentError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_recentError!, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      );
    }
    if (_recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 36, color: Color(0xFFD1D5DB)),
              SizedBox(height: 8),
              Text('Chưa có giao dịch nào', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recent.asMap().entries.map((entry) {
        final i = entry.key;
        final tx = entry.value;
        final incoming = tx.direction == 'in';
        final amountColor = incoming ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final bgColor = incoming ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
        final iconColor = incoming ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final title = tx.counterpartyName?.isNotEmpty == true
            ? (incoming ? tx.counterpartyName! : tx.counterpartyName!)
            : (incoming ? 'Nhận tiền' : 'Chuyển tiền');
        final desc = tx.description == null || tx.description!.isEmpty
            ? tx.transactionType : tx.description!;

        return Column(
          children: [
            if (i > 0) const Divider(height: 1, indent: 72),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(
                  incoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: iconColor, size: 20,
                ),
              ),
              title: Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                '${incoming ? '+' : '-'}${tx.amount} VND',
                style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}