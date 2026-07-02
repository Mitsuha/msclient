import 'package:flutter/cupertino.dart';

import 'package:desktop/features/models/control_panel_models.dart';

class AccountTable extends StatelessWidget {
  const AccountTable({super.key, required this.account});

  final AccountSummary account;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableRow(label: '账号', value: account.account),
        const _Divider(),
        _TableRow(label: '昵称', value: account.nickname),
        const _Divider(),
        _TableRow(label: '账户余额', value: account.balance),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14),
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE5E5EA))),
    );
  }
}
