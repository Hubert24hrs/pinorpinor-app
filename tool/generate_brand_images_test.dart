@Tags(<String>['tooling'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/theme/app_colors.dart';

/// Renders the app icon and splash artwork from the same design tokens the app
/// uses, rather than shipping hand-drawn PNGs that can drift from the brand.
///
/// The mark reproduces the website's logo tile: a white flame on the
/// rose-to-burgundy gradient (`--accent-gradient`). The flame is drawn as a
/// vector path rather than as an icon-font glyph, because the test environment
/// substitutes a placeholder font — a glyph would rasterise as a blank box.
///
/// This is a generator, not a test of app behaviour. `flutter test` with no
/// arguments runs `test/` only, so it never joins the ordinary suite.
/// Regenerate with:
///
///     flutter test tool/generate_brand_images_test.dart
///     dart run flutter_launcher_icons
///     dart run flutter_native_splash:create
void main() {
  testWidgets('generate brand images', (tester) async {
    // `toImage()` completes on the real event loop, which the fake-async test
    // zone would otherwise block for ever.
    await tester.runAsync(() async {
      // The full-bleed icon Play and the App Store use.
      await _writePng(
        path: 'assets/brand/app_icon.png',
        size: 1024,
        painter: const _BrandMarkPainter(fullBleed: true, flameScale: 0.52),
      );

      // Android adaptive foreground. The launcher masks the outer ~28% of an
      // adaptive layer, so the flame is drawn smaller and centred to survive a
      // circular, squircle or rounded-square mask.
      await _writePng(
        path: 'assets/brand/app_icon_foreground.png',
        size: 1024,
        painter: const _BrandMarkPainter(fullBleed: false, flameScale: 0.30),
      );

      // Splash artwork: the tile on transparency, so it sits on the ivory
      // window background rather than carrying its own square.
      await _writePng(
        path: 'assets/brand/splash_mark.png',
        size: 640,
        painter: const _BrandMarkPainter(fullBleed: false, flameScale: 0.34),
      );
    });
  });
}

Future<void> _writePng({
  required String path,
  required int size,
  required CustomPainter painter,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(size.toDouble(), size.toDouble()));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  if (data == null) throw StateError('Failed to encode $path');

  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );

  // ignore: avoid_print — this file is a build tool, not app code.
  print('wrote $path  ${size}x$size  ${data.lengthInBytes} bytes');
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.fullBleed, required this.flameScale});

  /// True for the store icon, where the gradient fills the whole square. False
  /// for the adaptive foreground and splash, where it is a centred tile.
  final bool fullBleed;

  /// Flame height as a fraction of the canvas.
  final double flameScale;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;

    if (fullBleed) {
      canvas.drawRect(
        canvasRect,
        Paint()..shader = AppColors.roseGradient.createShader(canvasRect),
      );
    } else {
      final tile = Rect.fromCenter(
        center: canvasRect.center,
        width: size.width * 0.56,
        height: size.height * 0.56,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.28)),
        Paint()..shader = AppColors.roseGradient.createShader(tile),
      );
    }

    final flameHeight = size.height * flameScale;
    final flameWidth = flameHeight * 0.78;
    final flameRect = Rect.fromCenter(
      center: canvasRect.center,
      width: flameWidth,
      height: flameHeight,
    );

    canvas.drawPath(
      _flamePath(flameRect),
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );
  }

  /// A filled flame silhouette, expressed in a 0–1 box and scaled into [rect].
  ///
  /// Normalised coordinates keep the shape resolution-independent: the same
  /// path produces a crisp 48px launcher icon and a 1024px store asset.
  Path _flamePath(Rect rect) {
    double x(double t) => rect.left + rect.width * t;
    double y(double t) => rect.top + rect.height * t;

    return Path()
      // Tip.
      ..moveTo(x(0.50), y(0.00))
      // Down the right shoulder.
      ..cubicTo(x(0.74), y(0.22), x(0.92), y(0.38), x(0.92), y(0.60))
      // Round the base on the right.
      ..cubicTo(x(0.92), y(0.83), x(0.74), y(1.00), x(0.50), y(1.00))
      // Round the base on the left.
      ..cubicTo(x(0.26), y(1.00), x(0.08), y(0.83), x(0.08), y(0.60))
      // Up the left side to the small inner curl.
      ..cubicTo(x(0.08), y(0.44), x(0.20), y(0.31), x(0.31), y(0.19))
      // The curl that reads as a second, inner tongue of flame.
      ..cubicTo(x(0.33), y(0.36), x(0.40), y(0.44), x(0.49), y(0.45))
      // Back up to the tip.
      ..cubicTo(x(0.58), y(0.33), x(0.57), y(0.15), x(0.50), y(0.00))
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
