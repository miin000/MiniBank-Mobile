import 'package:flutter/material.dart';

import '../api/loan_api.dart';

class LoanListWidget extends StatelessWidget {
  final List<Loan> loans;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final bool embedded;
  final ValueChanged<Loan>? onTap;

  const LoanListWidget({
    super.key,
    required this.loans,
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '--';
    final date = DateTime.tryParse(dateString);
    if (date == null) return dateString;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _loanCard(Loan loan) {
    final remaining = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final monthly = remaining <= 0
        ? 0
        : remaining / (loan.termMonths == 0 ? 1 : loan.termMonths);
    final status = loan.status.toLowerCase();
    final isClosed = status == 'closed' || status == 'completed';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(loan),
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
                      color: Color(0xFFFFF1E8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card_outlined,
                      color: Color(0xFFFF5A1F),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khoản vay ${loan.code}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1B3E),
                          ),
                        ),
                        Text(
                          loan.status.toLowerCase() == 'closed'
                              ? 'Đã đóng'
                              : 'Đang trả nợ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
                      'Dư nợ còn lại',
                      '${_formatCurrency(loan.outstandingPrincipal)} VND',
                      const Color(0xFFE11D48),
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'Thanh toán kế tiếp',
                      _formatDate(loan.nextDueDate),
                      Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isClosed ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isClosed ? const Color(0xFFE2E8F0) : const Color(0xFFFFEDD5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClosed ? 'Trạng thái' : 'Trả hằng tháng',
                      style: TextStyle(fontSize: 12, color: isClosed ? const Color(0xFF64748B) : const Color(0xFF7C2D12)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isClosed ? 'Đã đóng' : '${_formatCurrency(monthly.toStringAsFixed(0))} VND',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isClosed ? const Color(0xFF64748B) : const Color(0xFFFF5A1F),
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
    if (loans.isEmpty) {
      return _message(Icons.receipt_long_outlined, 'Bạn chưa có khoản vay');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      children: loans.map(_loanCard).toList(),
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
