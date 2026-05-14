import 'package:flutter/material.dart';

import '../api/loan_api.dart';
import '../api/authed_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class CreateLoanScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const CreateLoanScreen({super.key, required this.baseUrl, required this.storage, required this.identity});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loanProductIdCtrl = TextEditingController();
  final _disbursementAccountCtrl = TextEditingController();
  final _repaymentAccountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  bool _submitting = false;

  late LoanApi _loanApi;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
  }

  @override
  void dispose() {
    _loanProductIdCtrl.dispose();
    _disbursementAccountCtrl.dispose();
    _repaymentAccountCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final loan = await _loanApi.createLoan(
        loanProductId: int.parse(_loanProductIdCtrl.text.trim()),
        disbursementAccountId: int.parse(_disbursementAccountCtrl.text.trim()),
        repaymentAccountId: int.parse(_repaymentAccountCtrl.text.trim()),
        amount: _amountCtrl.text.trim(),
        purpose: _purposeCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo vay thành công')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký vay')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _loanProductIdCtrl,
                decoration: const InputDecoration(labelText: 'Loan product ID'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _disbursementAccountCtrl,
                decoration: const InputDecoration(labelText: 'Disbursement account ID'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _repaymentAccountCtrl,
                decoration: const InputDecoration(labelText: 'Repayment account ID'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose'),
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator() : const Text('Gửi yêu cầu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
