import 'package:flutter/material.dart';
import '../models/lost_found_item_model.dart';
import '../utils/theme_manager.dart';

class LostFoundCard extends StatefulWidget {
  final LostFoundItem item;
  final VoidCallback? onTap;
  final bool showStatus;
  final Widget? trailing;

  const LostFoundCard({
    super.key,
    required this.item,
    this.onTap,
    this.showStatus = false,
    this.trailing,
  });

  @override
  State<LostFoundCard> createState() => _LostFoundCardState();
}

class _LostFoundCardState extends State<LostFoundCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = LostFoundCategory.color(widget.item.category);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withOpacity(_glowAnimation.value * 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 15,
                spreadRadius: -3,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    // Image or category color indicator
                    if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        child: Image.network(
                          widget.item.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: categoryColor,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            child: Icon(LostFoundCategory.icon(widget.item.category), color: categoryColor, size: 28),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 6,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              categoryColor,
                              categoryColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: AppDimensions.spacingLg),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name
                          Text(
                            widget.item.itemName,
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeLg,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),

                          // Description preview
                          if (widget.item.description.isNotEmpty)
                            Text(
                              widget.item.description,
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeSm,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: AppDimensions.spacingXs),

                          // Location
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: AppDimensions.iconSm,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: AppDimensions.spacingXs),
                              Expanded(
                                child: Text(
                                  widget.item.foundLocation,
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeSm,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Date & finder
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: AppDimensions.iconSm,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: AppDimensions.spacingXs),
                              Text(
                                widget.item.foundAgo,
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeSm,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              Icon(
                                Icons.person_outline,
                                size: AppDimensions.iconSm,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: AppDimensions.spacingXs),
                              Expanded(
                                child: Text(
                                  widget.item.finderName,
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeSm,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: AppDimensions.spacingSm),

                    // Right side: category badge + optional status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                categoryColor.withOpacity(0.15),
                                categoryColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(
                              color: categoryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LostFoundCategory.icon(widget.item.category),
                                size: 12,
                                color: categoryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                LostFoundCategory.displayName(
                                  widget.item.category,
                                ),
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeXs,
                                  fontWeight: FontWeight.w700,
                                  color: categoryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status badge (optional)
                        if (widget.showStatus) ...[
                          const SizedBox(height: AppDimensions.spacingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.item.status.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                              border: Border.all(
                                color:
                                    widget.item.status.color.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.item.status.icon,
                                  size: 12,
                                  color: widget.item.status.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.item.status.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: widget.item.status.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Trailing widget (action buttons)
                        if (widget.trailing != null) ...[
                          const SizedBox(height: AppDimensions.spacingSm),
                          widget.trailing!,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
