import 'package:flutter/material.dart';

class GamePanel extends StatelessWidget {
  final Widget child;
  const GamePanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: const Color(0xDD14181F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.deepOrange, width: 2),
          ),
          child: SingleChildScrollView(child: child),
        ),
      );
}
