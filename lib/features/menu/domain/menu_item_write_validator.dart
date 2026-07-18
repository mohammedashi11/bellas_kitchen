import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_failure.dart';
import 'entities/menu_item.dart';

/// Write-side validation for menu items. Pure Dart, fully unit-testable.
///
/// This is the write-side complement of the read-only `'Other'` category
/// fallback: a menu item may only ever be WRITTEN with a real category from
/// [AppConstants.storableCategories]. `'Other'` (the defensive read fallback)
/// and the `'All'` UI sentinel are never storable values.
///
/// Returns null when [item] is valid, otherwise a [ValidationFailure]
/// describing the first problem found.
AppFailure? validateMenuItemWrite(MenuItem item) {
  if (item.name.trim().isEmpty) {
    return const ValidationFailure('Name cannot be empty.');
  }
  if (item.price <= 0) {
    return const ValidationFailure('Price must be greater than zero.');
  }
  if (!AppConstants.storableCategories.contains(item.category)) {
    return ValidationFailure(
      '"${item.category}" is not a valid category. Choose one of: '
      '${AppConstants.storableCategories.join(', ')}.',
    );
  }

  // Add-ons. A zero price is VALID (a free preference like "No Onions"); only a
  // negative one is rejected, since it would silently discount the item.
  final seenIds = <String>{};
  for (final addOn in item.availableAddOns) {
    if (addOn.name.trim().isEmpty) {
      return const ValidationFailure('Add-on name cannot be empty.');
    }
    if (addOn.price < 0) {
      return ValidationFailure(
          'Add-on "${addOn.name}" cannot have a negative price.');
    }
    // Ids are cart line identity: two add-ons sharing an id would make distinct
    // selections collapse into one cart line.
    if (!seenIds.add(addOn.id)) {
      return ValidationFailure(
          'Duplicate add-on id "${addOn.id}" on this item.');
    }
  }
  return null;
}

/// Form-level check for the pasted image URL (the primary image input while
/// Storage upload is gated off — see AppConstants.storageUploadEnabled).
///
/// EMPTY is allowed: every surface that renders `imageUrl` (admin list,
/// customer menu card, item detail, cart thumbnail) already shows a neutral
/// placeholder for an empty/broken URL. A non-empty value must be a plausible
/// absolute http(s) URL.
AppFailure? validateImageUrlInput(String raw) {
  final url = raw.trim();
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  final ok = uri != null &&
      uri.isAbsolute &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  if (!ok) {
    return const ValidationFailure(
        'Image URL must be a valid http(s) link, or leave it empty.');
  }
  return null;
}
