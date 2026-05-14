import 'package:flutter/material.dart';

import '../api/service_request_api.dart';
import '../api/authed_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const CreateServiceRequestScreen({super.key, required this.baseUrl, required this.storage, required this.identity});

  @override
  State<CreateServiceRequestScreen> createState() => _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTypeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController();
  bool _submitting = false;

  late ServiceRequestApi _serviceRequestApi;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _serviceRequestApi = ServiceRequestApi(api: api);
  }

  @override
  void dispose() {
    _requestTypeCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final req = await _serviceRequestApi.createServiceRequest(
        requestType: _requestTypeCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        priorityTag: _priorityCtrl.text.trim().isEmpty ? null : _priorityCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi yêu cầu thành công')));
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
      appBar: AppBar(title: const Text('Gửi yêu cầu dịch vụ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _requestTypeCtrl,
                decoration: const InputDecoration(labelText: 'Loại yêu cầu (vd: limit_change, info_update)'),
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
                validator: (v) => v == null || v.isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priorityCtrl,
                decoration: const InputDecoration(labelText: 'Priority tag (optional)'),
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
