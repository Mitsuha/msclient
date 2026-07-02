import 'package:flutter/cupertino.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6E6E73),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: child,
        ),
      ],
    );
  }
}
