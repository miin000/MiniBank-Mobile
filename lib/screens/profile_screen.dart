import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../api/profile_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'account_setup_screen.dart';
import 'change_password_screen.dart';
import 'kyc_screen.dart';
import 'pin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const ProfileScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;
  ProfileResponse? _profile;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final p = await api.me();
      if (!mounted) return;
      setState(() => _profile = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _rankLabel(String? rank) {
    return switch ((rank ?? '').toLowerCase()) {
      'kim_cuong' => 'Kim cương',
      'bach_kim' => 'Bạch kim',
      'vang' => 'Vàng',
      'bac' => 'Bạc',
      'dong' => 'Đồng',
      _ => 'Chưa xếp hạng',
    };
  }

  Color _rankColor(String? rank) {
    return switch ((rank ?? '').toLowerCase()) {
      'kim_cuong' => const Color(0xFF2563EB),
      'bach_kim' => const Color(0xFF64748B),
      'vang' => const Color(0xFFB45309),
      'bac' => const Color(0xFF71717A),
      _ => const Color(0xFF92400E),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final isActive = (p?.status ?? '').toLowerCase() == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản cá nhân'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFFFF4F4),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 13)),
            ),
          if (_error != null) const SizedBox(height: 12),
          if (p == null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(child: Text(_loading ? 'Đang tải...' : 'Không có dữ liệu')),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName?.isNotEmpty == true ? p.fullName! : 'Khách hàng',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.phone ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isActive ? 'Đã kích hoạt' : 'Chưa kích hoạt',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _rankLabel(p.customerRank),
                      style: TextStyle(
                        color: _rankColor(p.customerRank),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Thông tin cá nhân',
              children: [
                _InfoTile(label: 'Họ và tên', value: p.fullName ?? ''),
                _InfoTile(label: 'Email', value: p.email ?? ''),
                _InfoTile(label: 'Số điện thoại', value: p.phone ?? ''),
                _InfoTile(label: 'Ngày sinh', value: p.dob ?? ''),
                _InfoTile(label: 'Địa chỉ', value: p.address ?? ''),
              ],
            ),
            const SizedBox(height: 12),
            if (p.accounts.isNotEmpty)
              _SectionCard(
                title: 'Tài khoản ngân hàng',
                children: p.accounts
                    .map(
                      (a) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.credit_card, size: 20),
                        title: Text(a.accountName, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(a.accountNumber, style: const TextStyle(fontSize: 12)),
                        trailing: Text(a.status, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
              )
            else if (isActive)
              _SectionCard(
                title: 'Tài khoản ngân hàng',
                children: [
                  const Text(
                    'Bạn đã được duyệt KYC nhưng chưa có số tài khoản. Hãy tạo số tài khoản để giao dịch.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AccountSetupScreen(
                            baseUrl: widget.baseUrl,
                            storage: widget.storage,
                          ),
                        ),
                      );
                      if (created == true) {
                        await _load();
                      }
                    },
                    child: const Text('Tạo số tài khoản'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Bảo mật & xác thực',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline, size: 20),
                  title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Cập nhật mật khẩu đăng nhập', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordScreen(
                          baseUrl: widget.baseUrl,
                          storage: widget.storage,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined, size: 20),
                  title: Text(isActive ? 'KYC đã duyệt' : 'Xác thực KYC', style: const TextStyle(fontSize: 14)),
                  subtitle: const Text('Xác minh danh tính tài khoản', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: isActive
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KycScreen(
                                baseUrl: widget.baseUrl,
                                storage: widget.storage,
                              ),
                            ),
                          );
                          await _load();
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock, size: 20),
                  title: const Text('Thiết lập / Đổi PIN', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    p.hasTransactionPin ? 'PIN đã thiết lập' : 'Chưa thiết lập PIN',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final profile = _profile;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PinScreen(
                          baseUrl: widget.baseUrl,
                          storage: widget.storage,
                          hasExistingPin: profile?.hasTransactionPin ?? true,
                        ),
                      ),
                    );
                    await _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Thiết bị & khóa bảo mật',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices, size: 20),
                  title: const Text('Thiết bị hiện tại', style: TextStyle(fontSize: 14)),
                  subtitle: Text(p.deviceId ?? '', style: const TextStyle(fontSize: 12)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key, size: 20),
                  title: const Text('Public Key', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    p.hasPublicKey ? 'Đã kích hoạt' : 'Chưa kích hoạt',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: kIsWeb
                      ? null
                      : () async {
                          try {
                            final publicKeyPem = await widget.identity.getOrCreatePublicKeyPem();
                            final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
                            await api.setPublicKey(publicKeyPem: publicKeyPem);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã cập nhật public key')),
                            );
                            await _load();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
