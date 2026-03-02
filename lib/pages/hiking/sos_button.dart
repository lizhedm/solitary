import 'package:flutter/material.dart';
import 'sos_detail_page.dart';
import 'dart:math' as math;

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 1.5s long press for safety
    );
    _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onLongPressComplete();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressComplete() {
    setState(() {
      _isPressing = false;
    });
    _controller.reset();
    
    // Navigate to SOS Detail
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SOSDetailPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressing = true);
        _controller.forward();
      },
      onTapUp: (_) {
        if (_controller.status != AnimationStatus.completed) {
          setState(() => _isPressing = false);
          _controller.reverse();
        }
      },
      onTapCancel: () {
        setState(() => _isPressing = false);
        _controller.reverse();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Custom Progress Ring
          // Ensure it's larger than the button (80)
          SizedBox(
            width: 130,
            height: 130,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: RingPainter(
                    progress: _controller.value,
                    color: const Color(0xFFFF5252), // Bright red for SOS
                    width: 8.0,
                  ),
                );
              },
            ),
          ),
          
          // The Button
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + _controller.value * 0.1, // Slight pulse effect
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                    // White border to separate button from the ring
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD32F2F).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                      const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (_isPressing)
                         const Text('长按', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double width;

  RingPainter({required this.progress, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - width) / 2;

    // Draw background ring (optional, maybe faint)
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    if (progress > 0) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width;

      // -90 degrees (top) start, sweep based on progress * 360
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at 12 o'clock
        2 * math.pi * progress, // Sweep angle
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
