import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

/// Slider that zooms in when you slow down, so 42 → 41 is easy.
/// Fast drag keeps the full range. + / − still move one step.
class FineSlider extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final int? divisions;
  final double? step;
  final ValueChanged<double> onChanged;

  const FineSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.divisions,
    this.step,
  });

  /// 1 = crawling (full zoom), 0 = a flick (full range).
  /// Normal dragging stays out; only a real crawl zooms in.
  static double zoomFromSpeed(double pxPerMs) {
    if (pxPerMs <= 0.03) return 1;
    if (pxPerMs >= 0.22) return 0;
    final t = (pxPerMs - 0.03) / 0.19;
    return (1 - t) * (1 - t);
  }

  @override
  State<FineSlider> createState() => _FineSliderState();
}

class _FineSliderState extends State<FineSlider> {
  double _raw = 0;
  double _zoom = 0;
  double _speedEma = 0.4;
  double _slowMs = 0;
  DateTime? _lastMove;

  double get _range => widget.max - widget.min;

  double get _step {
    if (widget.step != null && widget.step! > 0) return widget.step!;
    if (widget.divisions != null && widget.divisions! > 0) {
      return _range / widget.divisions!;
    }
    return 1;
  }

  /// How much of the full range one track-width covers at this zoom.
  double get _window {
    final tight = _step * 10;
    return _range * (1 - _zoom) + tight * _zoom;
  }

  @override
  void initState() {
    super.initState();
    _raw = widget.value;
  }

  @override
  void didUpdateWidget(covariant FineSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value - _snap(_raw)).abs() > 0.0001) {
      _raw = widget.value;
    }
  }

  double _snap(double value) {
    final stepped = ((value - widget.min) / _step).round() * _step + widget.min;
    return stepped.clamp(widget.min, widget.max);
  }

  void _emit(double next) {
    final snapped = _snap(next);
    if ((snapped - widget.value).abs() <= 0.0001) return;
    HapticFeedback.selectionClick();
    widget.onChanged(snapped);
  }

  void _nudge(int dir) {
    _raw = (_snap(widget.value) + _step * dir).clamp(widget.min, widget.max);
    _emit(_raw);
  }

  void _updateZoom(double dx) {
    final now = DateTime.now();
    final last = _lastMove;
    _lastMove = now;
    final dtMs = last == null
        ? 16.0
        : now.difference(last).inMicroseconds / 1000.0;
    final dt = dtMs.clamp(8.0, 40.0);
    final speed = dx.abs() / dt;
    _speedEma = _speedEma * 0.8 + speed * 0.2;
    final target = FineSlider.zoomFromSpeed(_speedEma);
    if (target > _zoom) {
      _slowMs += dt;
      if (_slowMs < 240) return;
      _zoom += (target - _zoom) * 0.08;
    } else {
      _slowMs = 0;
      _zoom += (target - _zoom) * 0.42;
    }
    _zoom = _zoom.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = _zoom > 0.28;
    return Row(
      children: [
        _Nudge(icon: Icons.remove_rounded, onTap: () => _nudge(-1)),
        Expanded(
          child: SizedBox(
            height: zoomed ? 52 : 40,
            child: LayoutBuilder(
              builder: (context, box) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final t = (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
                    _raw = widget.min + t * _range;
                    _zoom = 0;
                    _speedEma = 0.4;
                    _slowMs = 0;
                    _emit(_raw);
                    setState(() {});
                  },
                  onPanStart: (_) {
                    _raw = widget.value;
                    _zoom = 0;
                    _speedEma = 0.4;
                    _slowMs = 0;
                    _lastMove = null;
                  },
                  onPanUpdate: (details) {
                    _updateZoom(details.delta.dx);
                    _raw += (details.delta.dx / box.maxWidth) * _window;
                    _raw = _raw.clamp(widget.min, widget.max);
                    _emit(_raw);
                    setState(() {});
                  },
                  onPanEnd: (_) => setState(() {
                    _zoom = 0;
                    _speedEma = 0.4;
                    _slowMs = 0;
                    _lastMove = null;
                  }),
                  onPanCancel: () => setState(() {
                    _zoom = 0;
                    _speedEma = 0.4;
                    _slowMs = 0;
                    _lastMove = null;
                  }),
                  child: CustomPaint(
                    painter: _TrackPainter(
                      value: _snap(widget.value),
                      min: widget.min,
                      max: widget.max,
                      step: _step,
                      zoom: _zoom,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _Nudge(icon: Icons.add_rounded, onTap: () => _nudge(1)),
      ],
    );
  }
}

class _Nudge extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Nudge({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.stroke),
          ),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final double step;
  final double zoom;

  const _TrackPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.zoom,
  });

  String _label(double v) {
    if (step >= 1) return v.round().toString();
    if (step >= 0.1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final range = max - min;
    final t = ((value - min) / range).clamp(0.0, 1.0);
    final cy = zoom > 0.28 ? size.height * 0.42 : size.height / 2;
    const trackH = 6.0;
    final left = 8.0;
    final right = size.width - 8;
    final x = left + t * (right - left);

    canvas.drawRRect(
      RRect.fromLTRBR(left, cy - trackH / 2, right, cy + trackH / 2, const Radius.circular(99)),
      Paint()..color = const Color(0xFF243044),
    );
    if (x > left + 1) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, cy - trackH / 2, x, cy + trackH / 2, const Radius.circular(99)),
        Paint()..color = AppColors.accentSoft,
      );
    }

    if (zoom > 0.22) {
      final spread = 7.0 + zoom * 14.0;
      final ticks = 4;
      final labelStyle = TextStyle(
        color: AppColors.accentSoft.withOpacity(0.35 + zoom * 0.55),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      );
      for (var i = -ticks; i <= ticks; i++) {
        final v = (value + i * step).clamp(min, max);
        if ((v - (value + i * step)).abs() > 0.0001) continue;
        final tx = x + i * spread;
        if (tx < left || tx > right) continue;
        canvas.drawCircle(
          Offset(tx, cy),
          i == 0 ? 0 : 1.4,
          Paint()..color = AppColors.accentSoft.withOpacity(0.25 + zoom * 0.45),
        );
        if (zoom > 0.45 && (i == -2 || i == 0 || i == 2 || i.abs() == ticks)) {
          final tp = TextPainter(
            text: TextSpan(text: _label(v), style: labelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(tx - tp.width / 2, cy + 9));
        }
      }
    }

    final r = 9.0 + zoom * 3.0;
    canvas.drawCircle(
      Offset(x, cy),
      r + 4,
      Paint()..color = AppColors.accentSoft.withOpacity(0.12 + zoom * 0.2),
    );
    canvas.drawCircle(Offset(x, cy), r, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.step != step ||
      old.zoom != zoom;
}
