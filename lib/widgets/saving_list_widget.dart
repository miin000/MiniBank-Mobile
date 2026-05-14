import 'package:flutter/material.dart';
import '../api/saving_api.dart';

class SavingListWidget extends StatelessWidget {
  final List<Saving> savings;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final bool embedded;

  const SavingListWidget({super.key, required this.savings, required this.loading, required this.error, required this.onRefresh, this.embedded = true});

  String _formatCurrency(String amount) {
    try {
      final v = double.tryParse(amount) ?? 0.0;
      return v.toStringAsFixed(0);
    } catch (_) {
      return amount;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (_) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('active') || lowerStatus.contains('open')) return Colors.green;
    if (lowerStatus.contains('pending') || lowerStatus.contains('processing')) return Colors.orange;
    if (lowerStatus.contains('closed') || lowerStatus.contains('completed')) return Colors.grey;
    if (lowerStatus.contains('submitted')) return Colors.blue;
    return Colors.grey;
  }

  Widget _savingCard(Saving saving) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Số hiệu: ${saving.code}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Tiền gốc: ${_formatCurrency(saving.principalAmount)} VND', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _getStatusColor(saving.status).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Text(saving.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(saving.status))),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lãi tính được', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('${_formatCurrency(saving.accruedInterestAmount)} VND', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lãi đã trả', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('${_formatCurrency(saving.postedInterestAmount)} VND', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
          ]),
          if (saving.maturityDate != null) ...[
            const SizedBox(height: 12),
            Text('Ngày đáo hạn: ${_formatDate(saving.maturityDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Lỗi: $error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
        ]),
      );
    }
    if (savings.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.savings_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Bạn chưa có sổ tiết kiệm'),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      children: savings.map(_savingCard).toList(),
    );
  }
}
