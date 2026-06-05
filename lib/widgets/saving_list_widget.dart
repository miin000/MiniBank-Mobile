import 'package:flutter/material.dart';

import '../api/saving_api.dart';

class SavingListWidget extends StatelessWidget {
  final List<Saving> savings;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final bool embedded;
  final ValueChanged<Saving>? onTap;

  const SavingListWidget({
    super.key,
    required this.savings,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.embedded = true,
    this.onTap,
  });

  String _formatCurrency(String amount) {
    final value = double.tryParse(amount) ?? 0;
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  }

  double _progress(Saving saving) {
    final open = saving.openDate == null
        ? null
        : DateTime.tryParse(saving.openDate!);
    final maturity = saving.maturityDate == null
        ? null
        : DateTime.tryParse(saving.maturityDate!);
    if (open == null || maturity == null) return 0.5;
    final total = maturity.difference(open).inDays;
    if (total <= 0) return 1;
    return DateTime.now().difference(open).inDays.clamp(0, total) / total;
  }

  Widget _savingCard(Saving saving) {
    final status = saving.status.toLowerCase();
    final isClosed = status == 'closed' || status == 'completed' || status == 'settled';
    final progress = isClosed ? 1.0 : _progress(saving);
    final name = saving.productName.isNotEmpty
        ? saving.productName
        : 'Sổ tiết kiệm';
    final term = saving.termValue > 0
        ? '${saving.termValue} tháng'
        : 'Có kỳ hạn';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(saving),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7FBEF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      color: Color(0xFF00A86B),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1B3E),
                          ),
                        ),
                        Text(
                          term,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D1B3E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Đã tất toán',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      'Số tiền gốc',
                      '${_formatCurrency(saving.principalAmount)} VND',
                      Colors.black,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'Lãi suất',
                      '${saving.actualInterestRate.toStringAsFixed(1)}%/năm',
                      const Color(0xFF00A86B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isClosed) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiến độ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0D1B3E)),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00A86B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: const Color(0xFF00B95D),
                    backgroundColor: const Color(0xFFF1F3F5),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFBF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4F6E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiền lãi đã cộng',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '+${_formatCurrency(saving.earnedInterestAmount)} VND',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00A86B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return isClosed ? Opacity(opacity: 0.65, child: card) : card;
  }

  Widget _metric(String label, String value, Color valueColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: valueColor,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null) {
      return _message(Icons.error_outline, 'Lỗi: $error', action: true);
    }
    if (savings.isEmpty) {
      return _message(Icons.savings_outlined, 'Bạn chưa có sổ tiết kiệm');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      children: savings.map(_savingCard).toList(),
    );
  }

  Widget _message(IconData icon, String text, {bool action = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text),
          if (action) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
          ],
        ],
      ),
    ),
  );
}
