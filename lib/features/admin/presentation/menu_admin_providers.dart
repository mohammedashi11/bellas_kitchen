import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../menu/domain/entities/menu_item.dart';
import '../../menu/presentation/providers/menu_providers.dart';
import '../data/menu_image_uploader.dart';

/// Uploader for menu item images (admin only).
final menuImageUploaderProvider =
    Provider<MenuImageUploader>((ref) => MenuImageUploader());

/// Live list of ALL menu items (including unavailable) for the admin menu
/// manager. Reuses the existing menuRepositoryProvider — no new repository.
/// Unwraps the Result stream; failures surface as the AsyncError.
final adminMenuItemsProvider = StreamProvider<List<MenuItem>>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  return repo.watchAllMenuItems().map(
        (result) => result.fold(
          onSuccess: (items) => items,
          onFailure: (failure) => throw failure,
        ),
      );
});
