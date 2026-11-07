import 'package:flutter/material.dart';

import '../game/trail_game.dart';

class PadButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final ValueChanged<bool> onChange;

  const PadButton({
    super.key,
    required this.icon,
    required this.onChange,
    this.size = 72,
    this.color = const Color(0x66000000),
  });

  @override
  State<PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<PadButton> {
  bool down = false;

  void _set(bool v) {
    if (down == v) return;
    setState(() => down = v);
    widget.onChange(v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: down ? const Color(0xBBFFFFFF) : widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: down
                ? [
                    BoxShadow(
                        color: widget.color.withAlpha(200),
                        blurRadius: 12,
                        spreadRadius: 2)
                  ]
                : null,
          ),
          child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.5),
        ),
      );
}

class ControlsOverlay extends StatelessWidget {
  final TrailGame game;
  const ControlsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Controles de inclinação (Empinar e Abaixar)
                Row(children: [
                  PadButton(
                      icon: Icons.rotate_left,
                      onChange: (v) => game.leanBack = v),
                  PadButton(
                      icon: Icons.rotate_right,
                      onChange: (v) => game.leanFwd = v),
                ]),

                // Controles de tração: Freio, Turbo e Aceleração
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  PadButton(
                    icon: Icons.stop,
                    color: const Color(0x99D32F2F),
                    onChange: (v) => game.brake = v,
                  ),
                  PadButton(
                    icon: Icons.bolt,
                    size: 68,
                    color: const Color(0x9900B0FF),
                    onChange: (v) => game.setTurbo(v),
                  ),
                  PadButton(
                    icon: Icons.keyboard_double_arrow_right,
                    size: 92,
                    color: const Color(0x992E7D32),
                    onChange: (v) => game.gas = v,
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}
