import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// يعرض صورة الدعاية بعرض البطاقة وارتفاع يتبع نسبة الصورة الفعلية (بدون قص جانبي أو سفلي داخل الإطار).
class PromoImageMemory extends StatefulWidget {
  const PromoImageMemory({
    super.key,
    required this.bytes,
    this.placeholder,
  });

  final Uint8List bytes;
  final Widget? placeholder;

  @override
  State<PromoImageMemory> createState() => _PromoImageMemoryState();
}

class _PromoImageMemoryState extends State<PromoImageMemory> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant PromoImageMemory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _aspect = null;
      _decode();
    }
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      img.dispose();
      if (!mounted || w <= 0 || h <= 0) return;
      setState(() => _aspect = w / h);
    } catch (_) {
      if (mounted) setState(() => _aspect = 16 / 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_aspect == null) {
      return SizedBox(
        height: 280,
        width: double.infinity,
        child: ColoredBox(
          color: const Color(0xFFEEF2F7),
          child: widget.placeholder ?? const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFFEEF2F7),
      child: AspectRatio(
        aspectRatio: _aspect!,
        child: Image.memory(
          widget.bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
