import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/result.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../menu_admin_providers.dart';
import '../theme/admin_colors.dart';
import 'menu_item_form_screen.dart';

/// Admin Menu Management — list of all menu items (including unavailable) with
/// availability toggle, edit, delete, and a FAB to add. Lives in the admin
/// shell's Menu tab; the shell provides the bottom nav.
class AdminMenuScreen extends ConsumerStatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  ConsumerState<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends ConsumerState<AdminMenuScreen> {
  // 'All' tab + storable categories. 'All' also keeps items whose category
  // read back as the out-of-band 'Other' fallback visible to the admin.
  static const String _tabAll = AppConstants.categoryAll;
  String _tab = _tabAll;

  final Set<String> _busy = {};
  final Map<String, String> _errors = {};

  Future<void> _toggleAvailability(MenuItem item, bool value) async {
    setState(() {
      _busy.add(item.id);
      _errors.remove(item.id);
    });
    final result =
        await ref.read(menuRepositoryProvider).setAvailability(item.id, value);
    if (!mounted) return;
    setState(() {
      _busy.remove(item.id);
      result.fold(
        onSuccess: (_) {},
        onFailure: (f) => _errors[item.id] = f.message,
      );
    });
  }

  Future<void> _confirmDelete(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${item.name}"?',
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary)),
        content: Text(
            'This permanently removes the item from the menu. This cannot be '
            'undone.',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AdminColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: AdminColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy.add(item.id);
      _errors.remove(item.id);
    });
    final result =
        await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
    if (!mounted) return;
    setState(() {
      _busy.remove(item.id);
      result.fold(
        onSuccess: (_) {},
        onFailure: (f) => _errors[item.id] = f.message,
      );
    });
  }

  void _openForm({MenuItem? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => MenuItemFormScreen(existing: existing),
      ),
    );
    // No manual refresh needed: watchAllMenuItems is a live snapshot stream.
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminMenuItemsProvider);
    final items = async.asData?.value ?? const <MenuItem>[];
    final filtered = _tab == _tabAll
        ? items
        : items.where((i) => i.category == _tab).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AdminColors.accent,
        foregroundColor: const Color(0xFF0A0E1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: Column(
        children: [
          _TopBar(),
          _CategoryTabs(
            selected: _tab,
            tabs: const [_tabAll, ...AppConstants.storableCategories],
            onSelect: (t) => setState(() => _tab = t),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AdminColors.accent)),
              error: (e, _) => _MessageBody(
                icon: Icons.cloud_off_rounded,
                title: 'Menu unavailable',
                message: e.toString().replaceFirst('Exception: ', ''),
              ),
              data: (_) => filtered.isEmpty
                  ? const _MessageBody(
                      icon: Icons.menu_book_rounded,
                      title: 'No items',
                      message:
                          'No menu items in this category yet. Tap + to add one.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                          color: AdminColors.border, height: 1),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return _MenuRow(
                          item: item,
                          busy: _busy.contains(item.id),
                          error: _errors[item.id],
                          onToggle: (v) => _toggleAvailability(item, v),
                          onEdit: () => _openForm(existing: item),
                          onDelete: () => _confirmDelete(item),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: AdminColors.textSecondary),
          const SizedBox(width: 12),
          Text('Menu Items',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.accentBright)),
          const Spacer(),
          const Icon(Icons.search_rounded, color: AdminColors.textSecondary),
        ],
      ),
    );
  }
}

// ─── Category tabs ────────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  final String selected;
  final List<String> tabs;
  final ValueChanged<String> onSelect;

  const _CategoryTabs({
    required this.selected,
    required this.tabs,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(tab),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: tab == selected
                        ? AdminColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: tab == selected
                        ? Border.all(color: AdminColors.border, width: 0.8)
                        : null,
                  ),
                  child: Text(tab,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tab == selected
                            ? AdminColors.textPrimary
                            : AdminColors.textSecondary,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Menu row ─────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final MenuItem item;
  final bool busy;
  final String? error;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuRow({
    required this.item,
    required this.busy,
    required this.error,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Unavailable rows render dimmed (like the mockup's greyed row).
    final dim = !item.isAvailable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with neutral placeholder for empty/broken URLs.
              Opacity(
                opacity: dim ? 0.45 : 1,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AdminColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AdminColors.border, width: 0.8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.imageUrl.trim().isEmpty
                      ? const Icon(Icons.image_outlined,
                          color: AdminColors.textHint, size: 26)
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AdminColors.inputFill),
                          errorWidget: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: AdminColors.textHint,
                              size: 26),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: dim
                                ? AdminColors.textSecondary
                                : AdminColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('\$${item.price.toStringAsFixed(2)}',
                        style: GoogleFonts.robotoMono(
                            fontSize: 14,
                            color: dim
                                ? AdminColors.textHint
                                : AdminColors.accentBright)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Edit / delete / availability
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconBtn(icon: Icons.edit_outlined, onTap: onEdit),
                      const SizedBox(width: 10),
                      _IconBtn(
                          icon: Icons.delete_outline_rounded,
                          onTap: onDelete),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.only(top: 8, right: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AdminColors.accent),
                            ),
                          )
                        : Switch(
                            value: item.isAvailable,
                            onChanged: onToggle,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AdminColors.accent,
                            inactiveThumbColor: AdminColors.textSecondary,
                            inactiveTrackColor: AdminColors.inputFill,
                          ),
                  ),
                ],
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AdminColors.danger, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(error!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AdminColors.danger)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: AdminColors.textSecondary, size: 21),
      ),
    );
  }
}

// ─── Message body (empty / error) ─────────────────────────────────────────────

class _MessageBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageBody({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminColors.textHint, size: 44),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AdminColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
