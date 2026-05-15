import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/contract_api.dart';
import '../auth/auth_storage.dart';

class ContractListScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const ContractListScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen> {
  late ContractApi _contractApi;

  List<ContractItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _contractApi = ContractApi(api: api);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _contractApi.getContracts();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(value);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) {
      return value;
    }
  }

  String _ownerLabel(ContractItem c) {
    final type = c.ownerType.toLowerCase();
    if (type == 'loan_application') return 'Khoan vay';
    if (type == 'saving') return 'So tiet kiem';
    return c.ownerType;
  }

  String _statusLabel(String? status) {
    final raw = (status ?? '').toLowerCase();
    if (raw == 'sent') return 'Da gui hop dong';
    if (raw == 'signed') return 'Da ky';
    if (raw == 'draft') return 'Ban nhap';
    if (raw == 'cancelled') return 'Da huy';
    if (raw == 'pending_signature') return 'Cho ky';
    return status ?? 'N/A';
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thu lai')),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Chua co hop dong nao', style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EAF0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  c.contractNumber?.isNotEmpty == true ? c.contractNumber! : 'Hop dong #${c.id}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(c.status),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              )
            ]),
            const SizedBox(height: 6),
            Text('Loai: ${_ownerLabel(c)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            Text('Ma giao dich: ${c.ownerId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.access_time, size: 12, color: Colors.black45),
              const SizedBox(width: 4),
              Text('Tao luc: ${_fmtDate(c.createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ]),
            if (c.fileUrl != null && c.fileUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('File: ${c.fileUrl}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Hop dong'),
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
      ),
    );
  }
}
