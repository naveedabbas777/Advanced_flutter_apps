import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lost_found_item_model.dart';
import '../models/user_model.dart';
import '../services/lost_found_service.dart';
import '../widgets/lost_found_card.dart';
import '../utils/theme_manager.dart';
import 'report_found_item_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  final LostFoundService _service = LostFoundService();
  String? _currentUserId;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _initAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    _fabController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  List<LostFoundItem> _filterByStatus(List<LostFoundItem> items) {
    if (_selectedFilter == 'All') return items;
    final status = LostFoundStatus.values.firstWhere(
      (s) => s.name == _selectedFilter,
      orElse: () => LostFoundStatus.pending,
    );
    return items.where((item) => item.status == status).toList();
  }

  void _showItemDetails(LostFoundItem item) {
    final dateStr =
        '${item.foundDate.day}/${item.foundDate.month}/${item.foundDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Status + Category badges
                Row(
                  children: [
                    _statusBadge(item.status),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: LostFoundCategory.color(item.category)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                        border: Border.all(
                          color: LostFoundCategory.color(item.category)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LostFoundCategory.icon(item.category),
                            size: 14,
                            color: LostFoundCategory.color(item.category),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LostFoundCategory.displayName(item.category),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: LostFoundCategory.color(item.category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Item image
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: Image.network(
                      item.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                ],

                // Item name
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeXxl,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),

                // Description
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeMd,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),

                // Info
                _infoRow(Icons.location_on, 'Found at', item.foundLocation),
                _infoRow(Icons.calendar_today, 'Date found', dateStr),
                if (item.finderContact != null &&
                    item.finderContact!.isNotEmpty)
                  _infoRow(Icons.phone, 'Contact', item.finderContact!),

                const SizedBox(height: AppDimensions.spacingMd),

                // Status timeline
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Timeline',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeMd,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      _timelineStep(
                        'Submitted',
                        item.createdAt != null
                            ? _formatDate(item.createdAt!)
                            : 'Unknown',
                        true,
                        Colors.blue,
                      ),
                      _timelineLine(
                        item.status == LostFoundStatus.approved ||
                            item.status == LostFoundStatus.rejected ||
                            item.status == LostFoundStatus.claimed,
                      ),
                      if (item.status == LostFoundStatus.rejected)
                        _timelineStep(
                          'Rejected',
                          item.updatedAt != null
                              ? _formatDate(item.updatedAt!)
                              : '—',
                          true,
                          Colors.red,
                        )
                      else ...[
                        _timelineStep(
                          'Admin Review',
                          item.status == LostFoundStatus.pending
                              ? 'Waiting...'
                              : item.approvedAt != null
                                  ? _formatDate(item.approvedAt!)
                                  : 'Done',
                          item.status != LostFoundStatus.pending,
                          Colors.green,
                        ),
                        _timelineLine(item.status == LostFoundStatus.claimed),
                        _timelineStep(
                          'Claimed by Owner',
                          item.status == LostFoundStatus.claimed
                              ? (item.claimedAt != null
                                  ? _formatDate(item.claimedAt!)
                                  : 'Yes')
                              : '—',
                          item.status == LostFoundStatus.claimed,
                          Colors.purple,
                        ),
                      ],
                    ],
                  ),
                ),

                // Admin note
                if (item.adminNote != null && item.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: item.status == LostFoundStatus.rejected
                          ? Colors.red[50]
                          : Colors.green[50],
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                      border: Border.all(
                        color: item.status == LostFoundStatus.rejected
                            ? Colors.red[200]!
                            : Colors.green[200]!,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message,
                          size: 18,
                          color: item.status == LostFoundStatus.rejected
                              ? Colors.red[600]
                              : Colors.green[600],
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Note',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeSm,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      item.status == LostFoundStatus.rejected
                                          ? Colors.red[700]
                                          : Colors.green[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.adminNote!,
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeMd,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(LostFoundStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(
      String label, String time, bool isActive, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : Colors.grey[300],
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isActive ? Icons.check : Icons.circle,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeMd,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.grey[800] : Colors.grey[500],
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeSm,
                  color: isActive ? Colors.grey[600] : Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineLine(bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Container(
        width: 2,
        height: 24,
        color: isActive ? Colors.grey[400] : Colors.grey[200],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeSm,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeMd,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _navigateToReport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ReportFoundItemScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your submissions')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE3F2FD),
              const Color(0xFFF8F9FA),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Header + filter chips
            AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _contentAnimation.value) * -30),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingMd,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.08),
                                  AppColors.primary.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppDimensions.spacingSm),
                                Expanded(
                                  child: Text(
                                    'Track the status of all items you have reported. Tap any item to see full details and admin feedback.',
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeSm,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spacingMd),

                          // Status filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', 'All'),
                                _buildFilterChip(
                                  LostFoundStatus.pending.name,
                                  'Pending',
                                  color: LostFoundStatus.pending.color,
                                ),
                                _buildFilterChip(
                                  LostFoundStatus.approved.name,
                                  'Approved',
                                  color: LostFoundStatus.approved.color,
                                ),
                                _buildFilterChip(
                                  LostFoundStatus.rejected.name,
                                  'Rejected',
                                  color: LostFoundStatus.rejected.color,
                                ),
                                _buildFilterChip(
                                  LostFoundStatus.claimed.name,
                                  'Claimed',
                                  color: LostFoundStatus.claimed.color,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Items stream
            Expanded(
              child: AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - _contentAnimation.value) * 50),
                    child: Opacity(
                      opacity: _contentAnimation.value,
                      child: StreamBuilder<List<LostFoundItem>>(
                        stream: _service
                            .getMySubmittedItemsStream(_currentUserId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingMd,
                                  ),
                                  Text(
                                    'Error loading your submissions',
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeLg,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final allItems = snapshot.data ?? [];
                          final filtered = _filterByStatus(allItems);

                          if (allItems.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.08,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      size: 56,
                                      color: AppColors.primary.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingLg,
                                  ),
                                  Text(
                                    'No submissions yet',
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeXl,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingSm,
                                  ),
                                  Text(
                                    'Found something on campus?\nTap the button below to report it!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeMd,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingXl,
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _navigateToReport,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Report Found Item'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusMd,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.filter_list_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingMd,
                                  ),
                                  Text(
                                    'No items with this status',
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeLg,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingLg,
                            ),
                            itemCount: filtered.length + 1, // +1 for stats card
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Stats summary card
                                return _buildStatsCard(allItems);
                              }
                              final item = filtered[index - 1];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.spacingMd,
                                ),
                                child: LostFoundCard(
                                  item: item,
                                  showStatus: true,
                                  onTap: () => _showItemDetails(item),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // FAB
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: FloatingActionButton.extended(
              onPressed: _navigateToReport,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: const Icon(Icons.add),
              label: const Text(
                'Report New Item',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(List<LostFoundItem> items) {
    final pending =
        items.where((i) => i.status == LostFoundStatus.pending).length;
    final approved =
        items.where((i) => i.status == LostFoundStatus.approved).length;
    final rejected =
        items.where((i) => i.status == LostFoundStatus.rejected).length;
    final claimed =
        items.where((i) => i.status == LostFoundStatus.claimed).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Submissions Overview',
            style: TextStyle(
              fontSize: AppDimensions.fontSizeLg,
              fontWeight: FontWeight.w800,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            children: [
              _statChip('Total', items.length, AppColors.primary),
              const SizedBox(width: AppDimensions.spacingSm),
              _statChip('Pending', pending, LostFoundStatus.pending.color),
              const SizedBox(width: AppDimensions.spacingSm),
              _statChip('Approved', approved, LostFoundStatus.approved.color),
              const SizedBox(width: AppDimensions.spacingSm),
              _statChip('Rejected', rejected, LostFoundStatus.rejected.color),
            ],
          ),
          if (claimed > 0) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              children: [
                _statChip('Claimed', claimed, LostFoundStatus.claimed.color),
                const Spacer(),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: AppDimensions.fontSizeXl,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, {Color? color}) {
    final isSelected = _selectedFilter == value;
    final chipColor = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        backgroundColor: Colors.white,
        selectedColor: chipColor,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: chipColor.withOpacity(0.3), width: 1),
        ),
      ),
    );
  }
}
