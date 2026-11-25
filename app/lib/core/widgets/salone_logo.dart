import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum SaloneLogoVariant { full, compact, iconOnly, monochrome }

enum SaloneLogoTone { lightBackground, darkBackground }

/// Scalable, Flutter-drawn brand mark & wordmark for SaloneMarket.
///
/// Combines a structured marketplace bag arch, an interwoven "S" trade ribbon,
/// and a warm gold trade accent — crisp at any resolution.
class SaloneLogo extends StatelessWidget {
  const SaloneLogo({
    super.key,
    this.variant = SaloneLogoVariant.full,
    this.tone = SaloneLogoTone.lightBackground,
    this.markSize = 40,
    this.showTagline = false,
  });

  final SaloneLogoVariant variant;
  final SaloneLogoTone tone;
  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final isMono = variant == SaloneLogoVariant.monochrome;
    final isDarkBg = tone == SaloneLogoTone.darkBackground;

    final wordColor = isDarkBg ? Colors.white : SaloneColors.primary;
    final accentWordColor = isMono
        ? wordColor
        : (isDarkBg ? SaloneColors.gold : SaloneColors.secondary);
    final taglineColor = isDarkBg
        ? SaloneColors.cream.withValues(alpha: 0.8)
        : SaloneColors.textSecondary;

    final mark = SizedBox(
      width: markSize,
      height: markSize,
      child: CustomPaint(
        painter: _SaloneMarkPainter(
          isMono: isMono,
          isDarkBg: isDarkBg,
        ),
      ),
    );

    if (variant == SaloneLogoVariant.iconOnly) {
      return mark;
    }

    final fontSize = variant == SaloneLogoVariant.compact
        ? (markSize * 0.56).clamp(16.0, 22.0)
        : (markSize * 0.54).clamp(18.0, 28.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: variant == SaloneLogoVariant.compact ? 8 : 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.05,
                ),
                children: [
                  TextSpan(
                    text: 'Salone',
                    style: TextStyle(color: wordColor),
                  ),
                  TextSpan(
                    text: 'Market',
                    style: TextStyle(color: accentWordColor),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                'Sierra Leone Commerce',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: taglineColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SaloneMarkPainter extends CustomPainter {
  const _SaloneMarkPainter({
    required this.isMono,
    required this.isDarkBg,
  });

  final bool isMono;
  final bool isDarkBg;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120.0;
    canvas.save();
    canvas.scale(s, s);

    final bgColor = isMono
        ? (isDarkBg ? Colors.white.withValues(alpha: 0.14) : SaloneColors.textPrimary)
        : (isDarkBg ? SaloneColors.cream : SaloneColors.primary);
    final bagColor = isMono
        ? Colors.white.withValues(alpha: 0.22)
        : (isDarkBg ? SaloneColors.secondary : SaloneColors.secondary);
    final handleColor = isMono
        ? Colors.white
        : SaloneColors.gold;
    final strokeColor = isMono ? Colors.white : SaloneColors.cream;

    // Rounded badge container
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 120, 120),
        const Radius.circular(28),
      ),
      bgPaint,
    );

    // Marketplace bag handle arch
    final handlePaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;
    final handlePath = Path()
      ..moveTo(43, 44)
      ..lineTo(43, 37)
      ..arcToPoint(
        const Offset(77, 37),
        radius: const Radius.circular(17),
        clockwise: true,
      )
      ..lineTo(77, 44);
    canvas.drawPath(handlePath, handlePaint);

    // Bag body
    final bagPaint = Paint()..color = bagColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 42, 72, 58),
        const Radius.circular(16),
      ),
      bagPaint,
    );

    // Stylized "S" trade ribbon
    final sPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.8
      ..strokeCap = StrokeCap.round;
    final sPath = Path()
      ..moveTo(73, 57)
      ..cubicTo(73, 50, 47, 49, 47, 58.5)
      ..cubicTo(47, 67, 73, 66.5, 73, 77.5)
      ..cubicTo(73, 86.5, 47, 87, 46, 79);
    canvas.drawPath(sPath, sPaint);

    // Warm gold trade dot
    if (!isMono) {
      canvas.drawCircle(
        const Offset(84, 54),
        4.8,
        Paint()..color = SaloneColors.gold,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SaloneMarkPainter oldDelegate) =>
      oldDelegate.isMono != isMono || oldDelegate.isDarkBg != isDarkBg;
}
