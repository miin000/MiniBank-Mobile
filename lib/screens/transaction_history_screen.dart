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
  late TransactionApi _transactionApi;

  final _searchCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  String _direction = 'all';
  String _status = 'all';

  List<TransactionSummary> _items = [];

  @override
  void initState() {
    super.initState();
    _transactionApi = TransactionApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _transactionApi.history(
        direction: _direction == 'all' ? null : _direction,
        status: _status == 'all' ? null : _status,
        query: _searchCtrl.text.trim(),
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtAmount(String raw) {
    try {
      final n = double.parse(raw);
      final s = n.toStringAsFixed(0);
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return buf.toString();
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã GD, STK, tên... ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _load();
                  },
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _direction,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'in', child: Text('Nhận tiền')),
                    DropdownMenuItem(value: 'out', child: Text('Chuyển tiền')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _direction = value);
                    _load();
                  },
                  decoration: const InputDecoration(labelText: 'Loại giao dịch'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'completed', child: Text('Thành công')),
                    DropdownMenuItem(value: 'pending', child: Text('Chờ xử lý')),
                    DropdownMenuItem(value: 'failed', child: Text('Thất bại')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                    _load();
                  },
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ]),
              )
            else if (_items.isEmpty)
              const Center(child: Text('Chưa có giao dịch nào'))
            else
              ..._items.map((tx) {
                final incoming = tx.direction == 'in';
                final color = incoming ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
                final icon = incoming ? Icons.call_received : Icons.send_rounded;
                final title = tx.counterpartyName?.isNotEmpty == true
                    ? (incoming ? 'Nhận tiền từ ${tx.counterpartyName}' : 'Chuyển tiền đến ${tx.counterpartyName}')
                    : (incoming ? 'Nhận tiền' : 'Chuyển tiền');
                final desc = tx.description == null || tx.description!.isEmpty
                    ? tx.transactionType
                    : tx.description!;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: incoming ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(title),
                    subtitle: Text(desc),
                    trailing: Text(
                      '${incoming ? '+' : '-'}${_fmtAmount(tx.amount)} đ',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
