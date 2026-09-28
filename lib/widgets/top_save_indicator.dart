import 'package:flutter/material.dart';

class TopSaveIndicator extends StatefulWidget {
  final DateTime lastSavedAt;
  final bool isCloud;

  const TopSaveIndicator({
    super.key,
    required this.lastSavedAt,
    this.isCloud = false,
  });

  @override
  State<TopSaveIndicator> createState() => _TopSaveIndicatorState();
}

class _TopSaveIndicatorState extends State<TopSaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  DateTime? _previousSavedAt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _scaleAnim = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _previousSavedAt = widget.lastSavedAt;
  }

  @override
  void didUpdateWidget(covariant TopSaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastSavedAt != _previousSavedAt) {
      _previousSavedAt = widget.lastSavedAt;
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          _controller.reverse();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.value == 0) {
            return const SizedBox.shrink();
          }

          return Opacity(
            opacity: _opacityAnim.value,
            child: SlideTransition(
              position: _slideAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D3E),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B4D3E).withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Pulse Check Icon
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F362A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    widget.isCloud
                        ? Icons.cloud_done_rounded
                        : Icons.check_circle_rounded,
                    color: const Color(0xFF4ADE80),
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isCloud ? 'Synced to Cloud' : 'Saved',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
