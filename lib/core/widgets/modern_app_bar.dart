import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A modern, tactile, and distinct App Bar designed to replace invisible
/// or non-existent headers across the attendance platform.
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final Color backgroundColor;
  final bool showBottomBorder;
  final VoidCallback? onLeadingPressed;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  const ModernAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.backgroundColor = Colors.white,
    this.showBottomBorder = true,
    this.onLeadingPressed,
    this.bottom,
    this.toolbarHeight = 64.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: ModernAppBarBackButton(
            onPressed: onLeadingPressed ?? () => Navigator.maybePop(context),
          ),
        ),
      );
    }

    Widget? centerTitleWidget;
    if (titleWidget != null) {
      centerTitleWidget = titleWidget;
    } else if (title != null) {
      centerTitleWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title!,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10213E),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showBottomBorder
            ? const Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10213E).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: toolbarHeight,
              child: Row(
                children: [
                  if (leadingWidget != null)
                    leadingWidget
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 12),
                  if (centerTitleWidget != null)
                    Expanded(child: centerTitleWidget)
                  else
                    const Spacer(),
                  if (actions != null) ...[
                    ...actions!,
                    const SizedBox(width: 16),
                  ] else
                    const SizedBox(width: 20),
                ],
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Circular tactile back button with clean shadow and border
class ModernAppBarBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ModernAppBarBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0610213E),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: Color(0xFF10213E),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern action icon button with optional badge and tooltip
class ModernAppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int? badgeCount;
  final Color iconColor;
  final Color backgroundColor;

  const ModernAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount,
    this.iconColor = const Color(0xFF10213E),
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 10,
                      minHeight: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
