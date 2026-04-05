import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _row('Subtotal', currency.format(subtotal)),
          const SizedBox(height: 10),
          _row('Desconto aplicado', currency.format(discount)),
          const Divider(height: 28),
          _row(
            'Total final',
            currency.format(total),
            valueStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            titleStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {TextStyle? titleStyle, TextStyle? valueStyle}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: titleStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}
