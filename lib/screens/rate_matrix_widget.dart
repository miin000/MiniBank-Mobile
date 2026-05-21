import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Public types ─────────────────────────────────────────────────────────────

class RateMatrixRow {
  final String label;
  final double amount;
  const RateMatrixRow({required this.label, required this.amount});
}

class RateMatrixSelection {
  final int    rowIndex;
  final int    colIndex;
  final double amount;
  final int    periods;     // months for saving; months for loan
  final double rate;
  const RateMatrixSelection({
    required this.rowIndex,
    required this.colIndex,
    required this.amount,
    required this.periods,
    required this.rate,
  });
}

/// Color scheme for a tier band.
class RateTier {
  final double maxRate;    // exclusive upper bound (use double.infinity for last tier)
  final Color  fillColor;
  final Color  textColor;
  const RateTier({required this.maxRate, required this.fillColor, required this.textColor});
}

// ─── Widget ───────────────────────────────────────────────────────────────────

/// A scrollable rate-matrix table.
///
/// Rows = money bands, columns = term bands.
/// Tapping a cell fires [onSelected] with the selected parameters so the
/// parent screen can compute and display the preview card.
///
/// Usage — Saving:
/// ```dart
/// RateMatrixWidget(
///   rows      : _sRows,
///   columns   : [1, 3, 6, 12, 24],
///   columnLabel: (m) => '${m}T',
///   rates     : _sRates,
///   tiers     : RateMatrixWidget.savingTiers,
///   selection : _sel,
///   onSelected: (s) => setState(() => _sel = s),
///   accentColor: _C.green,
/// )
/// ```
class RateMatrixWidget extends StatelessWidget {
  final List<RateMatrixRow> rows;
  final List<int>           columns;
  final String Function(int col) columnLabel;
  final List<List<double>>  rates;       // [rowIdx][colIdx]
  final List<RateTier>      tiers;
  final RateMatrixSelection? selection;
  final ValueChanged<RateMatrixSelection> onSelected;
  final Color accentColor;
  final Color accentDark;

  const RateMatrixWidget({
    super.key,
    required this.rows,
    required this.columns,
    required this.columnLabel,
    required this.rates,
    required this.tiers,
    required this.onSelected,
    required this.accentColor,
    required this.accentDark,
    this.selection,
  });

  // ── Preset tier palettes ─────────────────────────────────────────────────

  static const List<RateTier> savingTiers = [
    RateTier(maxRate: 5,            fillColor: Color(0xFFE1F5EE), textColor: Color(0xFF085041)),
    RateTier(maxRate: 6,            fillColor: Color(0xFF9FE1CB), textColor: Color(0xFF04342C)),
    RateTier(maxRate: double.infinity, fillColor: Color(0xFF1D9E75), textColor: Colors.white),
  ];

  static const List<RateTier> loanTiers = [
    RateTier(maxRate: 10,           fillColor: Color(0xFFE6F1FB), textColor: Color(0xFF0C447C)),
    RateTier(maxRate: 12,           fillColor: Color(0xFFB5D4F4), textColor: Color(0xFF042C53)),
    RateTier(maxRate: double.infinity, fillColor: Color(0xFF378ADD), textColor: Colors.white),
  ];

  // ── Helpers ──────────────────────────────────────────────────────────────

  RateTier _tier(double rate) =>
      tiers.firstWhere((t) => rate < t.maxRate, orElse: () => tiers.last);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: const Color(0xFFE8EAF0), width: 0.5),
        children: [
          _headerRow(),
          for (int ri = 0; ri < rows.length; ri++) _dataRow(ri),
        ],
      ),
    );
  }

  TableRow _headerRow() => TableRow(
    decoration: const BoxDecoration(color: Color(0xFFF1F3F9)),
    children: [
      _hCell('Số tiền', align: TextAlign.left),
      ...columns.map((c) => _hCell(columnLabel(c))),
    ],
  );

  Widget _hCell(String text, {TextAlign align = TextAlign.center}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7299))),
  );

  TableRow _dataRow(int ri) => TableRow(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(rows[ri].label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF0D1B3E))),
    ),
    for (int ci = 0; ci < columns.length; ci++) _rateCell(ri, ci),
  ]);

  Widget _rateCell(int ri, int ci) {
    final rate = rates[ri][ci];
    final tier = _tier(rate);
    final isSel = selection?.rowIndex == ri && selection?.colIndex == ci;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(RateMatrixSelection(
          rowIndex : ri,
          colIndex : ci,
          amount   : rows[ri].amount,
          periods  : columns[ci],
          rate     : rate,
        ));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: tier.fillColor,
          border: isSel ? Border.all(color: accentDark, width: 2) : null,
        ),
        child: Text(
          '${rate.toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSel ? accentDark : tier.textColor,
          ),
        ),
      ),
    );
  }
}

// ─── Legend widget ────────────────────────────────────────────────────────────

class RateMatrixLegend extends StatelessWidget {
  final List<RateTier> tiers;
  final List<String>   labels;

  const RateMatrixLegend({
    super.key,
    required this.tiers,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        tiers.length,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: tiers[i].fillColor,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(labels[i],
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7299))),
          ]),
        ),
      ),
    );
  }
}