import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/result.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../menu/domain/menu_item_write_validator.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../menu_admin_providers.dart';
import '../theme/admin_colors.dart';

/// The category choices offered by the form dropdown: storable categories
/// ONLY. Never includes the 'Other' read-fallback or the 'All' UI sentinel.
List<String> get menuFormCategoryOptions => AppConstants.storableCategories;

/// Add / Edit form for a menu item. Pass [existing] to edit (pre-filled);
/// null to create. Pushed as a full page from the admin menu list.
class MenuItemFormScreen extends ConsumerStatefulWidget {
  final MenuItem? existing;
  const MenuItemFormScreen({super.key, this.existing});

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _imageUrl;

  String? _category;
  bool _isBestSeller = false;
  bool _isAvailable = true;

  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _price = TextEditingController(
        text: e == null ? '' : e.price.toStringAsFixed(2));
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    // Only prefill a category the dropdown actually offers ('Other' → unset).
    _category = (e != null && menuFormCategoryOptions.contains(e.category))
        ? e.category
        : null;
    _isBestSeller = e?.isBestSeller ?? false;
    _isAvailable = e?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() => _error = null);
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null || !mounted) return; // user cancelled

    setState(() => _uploading = true);
    final bytes = await picked.readAsBytes();
    final result = await ref
        .read(menuImageUploaderProvider)
        .uploadMenuImage(bytes, fileName: picked.name);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      result.fold(
        onSuccess: (url) => _imageUrl.text = url,
        onFailure: (f) => _error = f.message,
      );
    });
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    final item = MenuItem(
      id: widget.existing?.id ?? '',
      name: _name.text,
      description: _description.text.trim(),
      price: price ?? 0,
      imageUrl: _imageUrl.text.trim(),
      category: _category ?? '',
      isBestSeller: _isBestSeller,
      isAvailable: _isAvailable,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    // Client-side validation (same pure validator the repository uses as its
    // backstop), plus form-specific checks.
    if (price == null && _price.text.trim().isNotEmpty) {
      setState(() => _error = 'Price must be a number.');
      return;
    }
    if (_category == null) {
      setState(() => _error = 'Please choose a category.');
      return;
    }
    final badUrl = validateImageUrlInput(_imageUrl.text);
    if (badUrl != null) {
      setState(() => _error = badUrl.message);
      return;
    }
    final invalid = validateMenuItemWrite(item);
    if (invalid != null) {
      setState(() => _error = invalid.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(menuRepositoryProvider);
    final result = _isEdit
        ? await repo.updateMenuItem(item)
        : await repo.addMenuItem(item);
    if (!mounted) return;

    final err = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: AdminColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AdminColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEdit ? 'Edit Menu Item' : 'Add Menu Item',
            style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Label('NAME'),
            const SizedBox(height: 8),
            _Field(controller: _name, hint: 'e.g. Classic Cheeseburger'),
            const SizedBox(height: 18),
            _Label('DESCRIPTION'),
            const SizedBox(height: 8),
            _Field(
                controller: _description,
                hint: 'Short menu description',
                maxLines: 3),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('PRICE (\$)'),
                      const SizedBox(height: 8),
                      _Field(
                        controller: _price,
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('CATEGORY'),
                      const SizedBox(height: 8),
                      _CategoryDropdown(
                        value: _category,
                        onChanged: (v) => setState(() => _category = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Label('IMAGE'),
            const SizedBox(height: 8),
            _ImagePickerSection(
              urlController: _imageUrl,
              uploading: _uploading,
              onPickFile: _uploading || _saving ? null : _pickAndUpload,
            ),
            const SizedBox(height: 18),
            _ToggleRow(
              label: 'Best Seller',
              value: _isBestSeller,
              onChanged: (v) => setState(() => _isBestSeller = v),
            ),
            const SizedBox(height: 10),
            _ToggleRow(
              label: 'Available',
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AdminColors.danger, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AdminColors.danger)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.accent,
                  foregroundColor: const Color(0xFF0A0E1A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saving || _uploading ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Color(0xFF0A0E1A)),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Add Item',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0A0E1A))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form pieces ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.robotoMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AdminColors.textSecondary));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: AdminColors.accent,
        style:
            GoogleFonts.poppins(fontSize: 15, color: AdminColors.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              GoogleFonts.poppins(fontSize: 15, color: AdminColors.textHint),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AdminColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AdminColors.surface,
          iconEnabledColor: AdminColors.textSecondary,
          hint: Text('Select…',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: AdminColors.textHint)),
          style: GoogleFonts.poppins(
              fontSize: 15, color: AdminColors.textPrimary),
          // storableCategories ONLY — 'Other' / 'All' are not offered.
          items: [
            for (final c in menuFormCategoryOptions)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  final TextEditingController urlController;
  final bool uploading;
  final VoidCallback? onPickFile;

  const _ImagePickerSection({
    required this.urlController,
    required this.uploading,
    required this.onPickFile,
  });

  // Device upload requires Firebase Storage (Blaze plan); the project runs on
  // Spark, so the button is shown DISABLED with a note rather than letting a
  // tap hit an opaque Storage error. Flip AppConstants.storageUploadEnabled
  // once Storage is enabled — MenuImageUploader is built and ready.
  static const bool _uploadEnabled = AppConstants.storageUploadEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PRIMARY: paste an image URL (live preview, zero-cost, works on Spark).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live preview of whatever URL is in the field.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.border, width: 0.8),
              ),
              clipBehavior: Clip.antiAlias,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: urlController,
                builder: (_, v, _) => v.text.trim().isEmpty
                    ? const Icon(Icons.image_outlined,
                        color: AdminColors.textHint, size: 28)
                    : Image.network(
                        v.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AdminColors.textHint,
                            size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Field(
                controller: urlController,
                hint: 'Paste an image URL (https://…)',
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // SECONDARY: device upload — gated off pending Firebase Storage.
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _uploadEnabled
                      ? AdminColors.accent
                      : AdminColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _uploadEnabled ? onPickFile : null,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AdminColors.accent),
                  )
                : Icon(Icons.upload_rounded,
                    color: _uploadEnabled
                        ? AdminColors.accent
                        : AdminColors.textHint,
                    size: 18),
            label: Text(uploading ? 'Uploading…' : 'Upload Image',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _uploadEnabled
                        ? AdminColors.accent
                        : AdminColors.textHint)),
          ),
        ),
        if (!_uploadEnabled) ...[
          const SizedBox(height: 6),
          Text('Image upload requires Firebase Storage (not enabled).',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AdminColors.textHint)),
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: AdminColors.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AdminColors.accent,
          ),
        ],
      ),
    );
  }
}
