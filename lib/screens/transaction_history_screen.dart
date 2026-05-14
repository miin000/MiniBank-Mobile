import 'dart:async';

import 'package:flutter/material.dart';

import '../api/transaction_api.dart';
import '../auth/auth_storage.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const TransactionHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _tabIndex = 0;
  String _direction = 'all';
  bool _loading = false;
  String? _error;
  List<TransactionSummary> _history = const [];
  List<TransactionSummary> _pending = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = TransactionApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final history = await api.history(
        direction: _direction,
        query: _searchCtrl.text.trim(),
      );
      final pending = await api.pending();
      if (!mounted) return;
      setState(() {
        _history = history;
        _pending = pending;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadAll);
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hh:$min - $dd/$mm/$yyyy';
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: 'Lịch sử',
            selected: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Stack(
            children: [
              _TabButton(
                label: 'Chờ duyệt',
                selected: _tabIndex == 1,
                onTap: () => setState(() => _tabIndex = 1),
              ),
              if (_pending.isNotEmpty)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pending.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Tìm theo người nhận, số tiền, nội dung...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: const [
                Icon(Icons.calendar_today_outlined, size: 18),
                SizedBox(width: 8),
                Text('Tháng 05/2026'),
                Spacer(),
                Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: const Icon(Icons.tune),
        ),
      ],
    );
  }

  Widget _buildDirectionTabs() {
    return Row(
      children: [
        _FilterPill(
          label: 'Tất cả',
          selected: _direction == 'all',
          onTap: () {
            setState(() => _direction = 'all');
            _loadAll();
          },
        ),
        const SizedBox(width: 8),
        _FilterPill(
          label: 'Tiền vào (+)',
          selected: _direction == 'in',
          onTap: () {
            setState(() => _direction = 'in');
            _loadAll();
          },
        ),
        const SizedBox(width: 8),
        _FilterPill(
          label: 'Tiền ra (-)',
          selected: _direction == 'out',
          onTap: () {
            setState(() => _direction = 'out');
            _loadAll();
          },
        ),
      ],
    );
  }

  Widget _buildList(List<TransactionSummary> items) {
    if (_tabIndex == 1) {
      return _buildPendingList(items);
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: Text('Chưa có giao dịch')),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final tx = items[index];
        final incoming = tx.direction == 'in';
        final color = incoming ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final icon = incoming ? Icons.arrow_downward : Icons.arrow_upward;
        final title = tx.counterpartyName?.isNotEmpty == true
            ? (incoming ? 'Nhận tiền từ ${tx.counterpartyName}' : 'Chuyển khoản đến ${tx.counterpartyName}')
            : (incoming ? 'Nhận tiền' : 'Chuyển khoản');
        final subtitle = tx.description?.isNotEmpty == true
            ? tx.description!
            : (tx.transactionType.isNotEmpty ? tx.transactionType : 'Giao dịch');
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: incoming ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${_formatDate(tx.createdAt)}  •  $subtitle'),
          trailing: Text(
            '${incoming ? '+' : '-'}${tx.amount}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 8),
      itemCount: items.length,
    );
  }

  Widget _buildPendingList(List<TransactionSummary> items) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: Text('Không có giao dịch chờ duyệt')),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final tx = items[index];
        final incoming = tx.direction == 'in';
        final amountColor = incoming ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final statusLabel = _pendingStatusLabel(tx.status);
        final reason = _pendingReason(tx.status);
        final counterpartyName = tx.counterpartyName?.isNotEmpty == true
            ? tx.counterpartyName!
            : (incoming ? 'Người gửi' : 'Người nhận');
        final counterpartyAccount = tx.counterpartyAccountNumber ?? '---';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCD9BD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE7D6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${incoming ? '+' : '-'}${tx.amount}',
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                counterpartyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('STK: $counterpartyAccount', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              _PendingRow(label: 'Nội dung', value: tx.description ?? '---'),
              _PendingRow(label: 'Thời gian tạo', value: _formatDate(tx.createdAt)),
              _PendingRow(label: 'Số tiền đang tạm giữ', value: '${tx.amount} VND'),
              if (reason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD9BD)),
                  ),
                  child: Text(
                    reason,
                    style: const TextStyle(color: Color(0xFFEA580C)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }

  String _pendingStatusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'pending_review' => 'Đang chờ kiểm tra',
      'pending_manager' => 'Chờ quản lý duyệt',
      _ => 'Đang xử lý',
    };
  }

  String? _pendingReason(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'pending_review' || normalized == 'pending_manager') {
      return 'Lý do cần kiểm tra: Số tiền vượt ngưỡng giao dịch lớn';
    }
    if (normalized == 'pending') {
      return 'Giao dịch đang được xử lý. Bạn sẽ nhận thông báo khi có kết quả.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = _tabIndex == 0 ? _history : _pending;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildTabs(),
            const SizedBox(height: 16),
            if (_tabIndex == 1)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Giao dịch chờ duyệt\nSố tiền sẽ được tạm giữ trong thời gian chờ xử lý. Bạn sẽ nhận thông báo khi có kết quả.',
                        style: TextStyle(color: Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ),
              ),
            if (_tabIndex == 1) const SizedBox(height: 12),
            _buildSearch(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            _buildDirectionTabs(),
            const SizedBox(height: 16),
            _buildList(items),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final String label;
  final String value;

  const _PendingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D4ED8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF1D4ED8) : Colors.black12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF2563EB) : Colors.black12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
