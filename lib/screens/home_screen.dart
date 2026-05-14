import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../api/account_api.dart';
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
import 'qr_screen.dart';
import 'transfer_screen.dart';
import 'transaction_history_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  AuthUser? _user;
  int _navIndex = 0;
  AccountSummary? _summary;
  List<TransactionSummary> _recent = const [];
  bool _loadingSummary = false;
  bool _loadingRecent = false;
  bool _loadingProfile = false;
  bool _hideBalance = true;
  String? _summaryError;
  String? _recentError;
  String? _profileStatus;
  int _profileAccountCount = 0;

  @override
  void initState() {
    super.initState();
    widget.storage.getUser().then((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
    _loadSummary();
    _loadRecent();
    _loadProfile();
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
      SnackBar(content: Text('$feature đang phát triển')),
    );
  }

  Future<void> _openTransfer() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );
    if (completed == true) {
      await _loadSummary();
      await _loadRecent();
    }
  }

  Future<void> _openQr() async {
    final needsReload = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => QrScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );

    if (needsReload == true && mounted) {
      await _loadSummary();
      await _loadRecent();
    }
  }

  void _openKyc() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KycScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );
  }

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

  void _openAccountSetup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountSetupScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
        ),
      ),
    );
    if (created == true) {
      await _loadSummary();
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
    });

    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final profile = await api.me();
      if (!mounted) return;
      setState(() {
        _profileStatus = profile.status;
        _profileAccountCount = profile.accounts.length;
      });
    } catch (_) {
      // Profile data is optional for home screen.
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final summary = await api.summary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('No account is assigned')) {
        final status = (_profileStatus ?? '').toLowerCase();
        if (status == 'active') {
          setState(() => _summaryError = 'Bạn đã được duyệt KYC. Hãy tạo số tài khoản để sử dụng dịch vụ.');
        } else {
          setState(() => _summaryError = 'Bạn chưa có tài khoản. Hãy hoàn tất KYC và chờ admin duyệt.');
        }
      } else {
        setState(() => _summaryError = msg);
      }
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadRecent() async {
    setState(() {
      _loadingRecent = true;
      _recentError = null;
    });

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

  String _rankLabel(String? rank) {
    if (rank == null || rank.isEmpty) return 'Chưa xếp hạng';
    return switch (rank.toLowerCase()) {
      'vip' => 'VIP',
      'vang' => 'Vàng',
      'bac' => 'Bạc',
      'dong' => 'Đồng',
      _ => rank,
    };
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (color ?? Colors.blue).withValues(alpha: 31),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color ?? Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final name = _displayName();
    final summary = _summary;
    final isActive = (_profileStatus ?? '').toLowerCase() == 'active';
    final hasAccount = summary != null || _profileAccountCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniBank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => _comingSoon('Thông báo'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.storage.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    baseUrl: widget.baseUrl,
                    api: widget.api,
                    storage: widget.storage,
                    identity: widget.identity,
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$greeting, $name',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(_rankLabel(summary?.customerRank))),
              Chip(label: Text(isActive ? 'Da xac thuc' : 'Chua xac thuc')),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (!hasAccount && _summaryError != null) {
                if (isActive) {
                  _openAccountSetup();
                } else {
                  _openKyc();
                }
                return;
              }
              _openProfile();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C3FAA), Color(0xFF1C5DD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E40AF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tài khoản', style: TextStyle(color: Colors.white70)),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary == null
                              ? (_loadingSummary ? 'Đang tải...' : 'Chưa có dữ liệu')
                              : (_hideBalance ? '•••••• VND' : '${summary.availableBalance} VND'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: summary == null
                            ? null
                            : () {
                                setState(() => _hideBalance = !_hideBalance);
                              },
                        icon: Icon(
                          _hideBalance ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: summary == null
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: summary.accountNumber));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã sao chép STK ${summary.accountNumber}')),
                            );
                          },
                    icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                    label: Text(
                      summary == null ? 'Sao chép STK' : 'STK: ${summary.accountNumber}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_summaryError != null) ...[
                    const SizedBox(height: 6),
                    Text(_summaryError!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (isActive && !hasAccount) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _loadingProfile ? null : _openAccountSetup,
                        child: const Text('Tao so tai khoan'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  icon: Icons.send_rounded,
                  label: 'Chuyển tiền',
                  color: const Color(0xFF377DFF),
                  onTap: _openTransfer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAction(
                  icon: Icons.call_received,
                  label: 'Nhận tiền',
                  color: const Color(0xFF22C55E),
                  onTap: () => _comingSoon('Nhận tiền'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAction(
                  icon: Icons.savings_outlined,
                  label: 'Tiết kiệm',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _comingSoon('Tiết kiệm'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAction(
                  icon: Icons.query_stats,
                  label: 'Thống kê',
                  color: const Color(0xFFF97316),
                  onTap: () => _comingSoon('Thống kê'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 51),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tips_and_updates, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cố vấn tài chính AI\nĐang phát triển. Sắp có gợi ý chi tiêu và tiết kiệm theo dữ liệu thực tế.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giao dịch gần đây', style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: () => _comingSoon('Xem tất cả'), child: const Text('Xem tất cả')),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                if (_loadingRecent)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Đang tải giao dịch...'),
                  )
                else if (_recentError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_recentError!, style: const TextStyle(fontSize: 12)),
                  )
                else if (_recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Chưa có giao dịch'),
                  )
                else
                  ..._recent.map((tx) {
                    final incoming = tx.direction == 'in';
                    final color = incoming ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
                    final icon = incoming ? Icons.call_received : Icons.send_rounded;
                    final title = tx.counterpartyName?.isNotEmpty == true
                        ? (incoming ? 'Nhận tiền từ ${tx.counterpartyName}' : 'Chuyển tiền đến ${tx.counterpartyName}')
                        : (incoming ? 'Nhận tiền' : 'Chuyển tiền');
                    final desc = tx.description == null || tx.description!.isEmpty
                        ? tx.transactionType
                        : tx.description!;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: incoming ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(title),
                          subtitle: Text(desc),
                          trailing: Text(
                            '${incoming ? '+' : '-'}${tx.amount}',
                            style: TextStyle(color: color),
                          ),
                          onTap: () => _comingSoon('Chi tiết giao dịch'),
                        ),
                        if (tx != _recent.last) const Divider(height: 12),
                      ],
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _openProfile,
            child: const Text('Hồ sơ / Đổi mật khẩu / PIN'),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            setState(() => _navIndex = 0);
            return;
          }
          if (index == 2) {
            _openQr();
            setState(() => _navIndex = 0);
            return;
          }
          if (index == 4) {
            _openProfile();
            setState(() => _navIndex = 0);
            return;
          }
          if (index == 1) {
            _openHistory();
            setState(() => _navIndex = 0);
            return;
          }
          final label = switch (index) {
            1 => 'Lịch sử',
            3 => 'Tiện ích',
            _ => 'Tính năng',
          };
          _comingSoon(label);
          setState(() => _navIndex = 0);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_rounded), label: 'Quét QR'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Tiện ích'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
