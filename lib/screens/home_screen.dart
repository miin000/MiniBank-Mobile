import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../auth/auth_models.dart';
import '../profile/profile_models.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthApi api;
  final AuthStorage storage;

  const HomeScreen({super.key, required this.api, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AuthUser? _user;
  ProfileResponse? _profile;
  String? _token;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.storage.getUser().then((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await widget.storage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Missing access token');
      }
      _token = token;

      final profile = await widget.api.getProfile(token: token);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await widget.storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          api: widget.api,
          storage: widget.storage,
        ),
      ),
      (route) => false,
    );
  }

  int? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  Future<void> _showChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_token == null) return;
                    if (newCtrl.text.trim().length < 6) {
                      setState(() => error = 'Mật khẩu mới tối thiểu 6 ký tự');
                      return;
                    }
                    try {
                      await widget.api.changePassword(
                        token: _token!,
                        oldPassword: oldCtrl.text,
                        newPassword: newCtrl.text,
                      );
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đổi mật khẩu thành công')),
                      );
                    } catch (e) {
                      setState(() => error = e.toString());
                    }
                  },
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );

    oldCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _profile?.fullName ?? '');
    final addressCtrl = TextEditingController(text: _profile?.address ?? '');
    DateTime? selectedDob = _profile?.dob;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Chỉnh sửa thông tin'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Ngày sinh',
                      hintText: selectedDob == null
                          ? 'Chọn ngày'
                          : '${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDob ?? DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(now.year, now.month, now.day),
                      );
                      if (picked != null) {
                        setState(() => selectedDob = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_token == null) return;
                    try {
                      final updated = await widget.api.updateProfile(
                        token: _token!,
                        fullName: nameCtrl.text.trim().isEmpty
                            ? null
                            : nameCtrl.text.trim(),
                        dob: selectedDob,
                        address: addressCtrl.text.trim().isEmpty
                            ? null
                            : addressCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      setState(() => _profile = updated);
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật thông tin')),
                      );
                    } catch (e) {
                      setState(() => error = e.toString());
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _showPinDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? error;
    final hasPin = _profile?.hasTransactionPin ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(hasPin ? 'Đổi PIN giao dịch' : 'Thiết lập PIN giao dịch'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPin) ...[
                    TextField(
                      controller: oldCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'PIN cũ (6 số)'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: newCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'PIN mới (6 số)'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_token == null) return;
                    if (newCtrl.text.trim().length != 6) {
                      setState(() => error = 'PIN phải đúng 6 số');
                      return;
                    }
                    try {
                      await widget.api.setTransactionPin(
                        token: _token!,
                        oldPin: oldCtrl.text.trim().isEmpty ? null : oldCtrl.text,
                        newPin: newCtrl.text,
                      );
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                      await _loadProfile();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cập nhật PIN thành công')),
                      );
                    } catch (e) {
                      setState(() => error = e.toString());
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    oldCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _showDeviceSheet() async {
    final deviceId = _profile?.deviceId ?? 'Chưa có thông tin thiết bị';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thiết bị đăng nhập',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(deviceId, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất khỏi thiết bị này'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName = (profile?.fullName?.trim().isNotEmpty ?? false)
        ? profile!.fullName!.trim()
        : (_user?.phone ?? _user?.username ?? 'Khách hàng');
    final age = _ageFromDob(profile?.dob);
    final accountNumber = profile?.accounts.isNotEmpty == true
        ? profile!.accounts.first.accountNumber
        : '---';
    final rank = (profile?.customerRank?.trim().isNotEmpty ?? false)
        ? profile!.customerRank!.trim()
        : 'Vàng';
    final status = profile?.status ?? 'active';
    const creditScore = 750;
    const creditMax = 1000;
    const transferLimit = '50.000.000 VND/ngày';
    const withdrawLimit = '100.000.000 VND/ngày';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'STK: $accountNumber',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rank,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            _SectionCard(
              title: 'Thông tin tài khoản',
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Họ và tên',
                  value: displayName,
                ),
                _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Tuổi',
                  value: age == null ? 'Chưa cập nhật' : '$age tuổi',
                ),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile?.email ?? '---',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ',
                  value: profile?.address ?? 'Chưa cập nhật',
                ),
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Trạng thái',
                  value: status,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Chỉnh sửa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Hạn mức giao dịch',
              children: const [
                _InfoRow(
                  icon: Icons.swap_horiz,
                  label: 'Hạn mức chuyển tiền',
                  value: transferLimit,
                ),
                _InfoRow(
                  icon: Icons.money_outlined,
                  label: 'Hạn mức rút tiền',
                  value: withdrawLimit,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Điểm tín dụng',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hạng tín dụng: Tốt'),
                    Text('$creditScore/$creditMax'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: creditScore / creditMax,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Cài đặt bảo mật',
              children: [
                _ActionRow(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Thay đổi mật khẩu đăng nhập',
                  onTap: _showChangePasswordDialog,
                ),
                _ActionRow(
                  icon: Icons.pin_outlined,
                  title: 'Mã PIN giao dịch',
                  subtitle: (_profile?.hasTransactionPin ?? false)
                      ? 'Đã thiết lập PIN'
                      : 'Thiết lập mã số bảo mật',
                  onTap: _showPinDialog,
                ),
                _ActionRow(
                  icon: Icons.devices_other_outlined,
                  title: 'Quản lý thiết bị',
                  subtitle: 'Xem và đăng xuất thiết bị đăng nhập',
                  onTap: _showDeviceSheet,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        onTap: (index) {
          if (index == 4) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng đang phát triển')),
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_rounded), label: 'Quét QR'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Tiện ích'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.blueGrey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.blueGrey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
