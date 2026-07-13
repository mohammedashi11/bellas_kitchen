import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/utils/result.dart';

/// Uploads menu item images to Firebase Storage under `menu_items/` and
/// returns the public download URL to store as `MenuItem.imageUrl`.
///
/// CURRENTLY GATED OFF: Firebase Storage requires the Blaze plan and the
/// project runs on Spark, so the form's upload button is disabled (see
/// AppConstants.storageUploadEnabled) and the paste-URL path is the primary
/// image input. This class is complete and ready — enabling Storage and
/// flipping that flag turns uploads on with no further code changes.
///
/// Takes raw BYTES (`putData`), not a file path, so the same code works on web
/// (image_picker's web implementation only exposes bytes) and mobile alike.
/// The Storage instance is resolved defensively like the other repositories.
class MenuImageUploader {
  final FirebaseStorage? _storage;

  MenuImageUploader({FirebaseStorage? storage})
      : _storage = storage ?? _tryStorage();

  static FirebaseStorage? _tryStorage() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  /// Generous cap so a large image on a slow connection can finish, but a dead
  /// connection can't hang the form forever.
  static const _uploadTimeout = Duration(seconds: 45);

  Future<Result<String>> uploadMenuImage(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final storage = _storage;
    if (storage == null) {
      return const Failure(
          NetworkFailure('Image upload is unavailable right now.'));
    }
    if (bytes.isEmpty) {
      return const Failure(ValidationFailure('The selected image is empty.'));
    }

    try {
      final ext = _extensionOf(fileName);
      final path =
          'menu_items/${DateTime.now().millisecondsSinceEpoch}_${_sanitize(fileName)}';
      final ref = storage.ref(path);
      await ref
          .putData(bytes, SettableMetadata(contentType: _contentTypeFor(ext)))
          .timeout(_uploadTimeout);
      final url = await ref.getDownloadURL().timeout(_uploadTimeout);
      return Success(url);
    } on FirebaseException catch (e) {
      return Failure(_mapStorage(e.code, e.message));
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('timeout')) {
        return const Failure(NetworkFailure(
            'Upload timed out. Check your connection and try again.'));
      }
      return const Failure(
          UnknownFailure('Could not upload the image. Please try again.'));
    }
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String _sanitize(String fileName) =>
      fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _contentTypeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };

  AppFailure _mapStorage(String code, String? message) {
    switch (code) {
      case 'unauthorized':
      case 'unauthenticated':
        return const UnauthorizedFailure(
            "You don't have permission to upload images.");
      case 'quota-exceeded':
        return const ServerFailure('Storage quota exceeded.');
      case 'retry-limit-exceeded':
        return const NetworkFailure(
            'Upload kept failing. Check your connection and try again.');
      case 'canceled':
        return const UnknownFailure('Upload was cancelled.');
      default:
        return UnknownFailure(message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Could not upload the image. Please try again.');
    }
  }
}
