import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum PZButtonStyle { primary, secondary, ghost, danger }

class PZButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PZButtonStyle style;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const PZButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PZButtonStyle.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (style) {
      PZButtonStyle.primary => AppColors.primary,
      PZButtonStyle.secondary => AppColors.secondary,
      PZButtonStyle.ghost => Colors.transparent,
      PZButtonStyle.danger => AppColors.error,
    };
    final fg = switch (style) {
      PZButtonStyle.primary => AppColors.background,
      PZButtonStyle.secondary => AppColors.background,
      PZButtonStyle.ghost => AppColors.textSecondary,
      PZButtonStyle.danger => Colors.white,
    };

    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: style == PZButtonStyle.ghost
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.textHint, width: 1.5),
                  )
                : null,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
