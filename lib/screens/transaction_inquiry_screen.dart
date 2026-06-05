import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/service_request_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class TransactionInquiryScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const TransactionInquiryScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<TransactionInquiryScreen> createState() =>
      _TransactionInquiryScreenState();
}

class _TransactionInquiryScreenState extends State<TransactionInquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionCodeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  bool _submitting = false;
  late ServiceRequestApi _serviceRequestApi;

  @override
  void initState() {
    super.initState();
    _serviceRequestApi = ServiceRequestApi(
      api: AuthedApi(
        baseUrl: widget.baseUrl,
        storage: widget.storage,
      ),
    );
  }

  @override
  void dispose() {
    _transactionCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final transactionCode = _transactionCodeCtrl.text.trim();
      final description = _descriptionCtrl.text.trim();

      await _serviceRequestApi.createServiceRequest(
        requestType: 'transaction_inquiry',
        title: 'Tra cứu giao dịch $transactionCode',
        description: description.isEmpty
            ? 'Yêu cầu tra cứu giao dịch mã $transactionCode'
            : description,
        priorityTag: null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gửi yêu cầu tra cứu thành công')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu giao dịch'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _transactionCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã giao dịch',
                  hintText: 'VD: TXN202606040001',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập mã giao dịch';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả vấn đề',
                  hintText: 'VD: Đã bị trừ tiền nhưng người nhận chưa nhận',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gửi yêu cầu tra cứu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}