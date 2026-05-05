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

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final isActive = (p?.status ?? '').toLowerCase() == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
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
              Text('SĐT: ${p.phone ?? ''}'),
              const SizedBox(height: 4),
              Text('Email: ${p.email ?? ''}'),
              const SizedBox(height: 4),
              Text('Trạng thái: ${p.status ?? ''}'),
              const SizedBox(height: 4),
              Text('PIN: ${p.hasTransactionPin ? 'Đã thiết lập' : 'Chưa thiết lập'}'),
              const SizedBox(height: 4),
              Text('PublicKey: ${p.hasPublicKey ? 'Đã có' : 'Chưa có'}'),
              const SizedBox(height: 4),
              Text('DeviceId: ${p.deviceId ?? ''}'),
              const SizedBox(height: 16),
              if (p.accounts.isNotEmpty) ...[
                Text('Tài khoản:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...p.accounts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${a.accountNumber} - ${a.accountName} (${a.status})'),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if ((p.status ?? '').toLowerCase() == 'active') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Ban da duoc duyet KYC nhung chua co so tai khoan. Hay tao so tai khoan de chuyen tien va tao QR.',
                  ),
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
                  child: const Text('Tao so tai khoan'),
                ),
                const SizedBox(height: 16),
              ],
            ],
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(
                      baseUrl: widget.baseUrl,
                      storage: widget.storage,
                    ),
                  ),
                );
              },
              child: const Text('Đổi mật khẩu'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: isActive
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
              child: Text(isActive ? 'KYC da duyet' : 'Xac thuc KYC'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
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
              child: const Text('Thiết lập / Đổi PIN'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: kIsWeb
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
              child: const Text('Gửi lại Public Key'),
            ),
          ],
        ),
      ),
    );
  }
}
