import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_order_repository.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/place_order_usecase.dart';

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => FirestoreOrderRepository());

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>(
  (ref) => PlaceOrderUseCase(
    ref.watch(orderRepositoryProvider),
    ref.watch(authRepositoryProvider),
  ),
);

/// Live status for a single order. Unwraps the repository's `Result` stream
/// into an [AsyncValue]: Success → data, Failure → the `AppFailure` as the
/// AsyncError (the UI reads its `.message`).
final orderTrackingProvider = StreamProvider.family<Order, String>(
  (ref, orderId) {
    final repo = ref.watch(orderRepositoryProvider);
    return repo.watchOrder(orderId).map(
          (result) => result.fold(
            onSuccess: (order) => order,
            onFailure: (failure) => throw failure,
          ),
        );
  },
);

/// Live list of ALL orders (admin Live Orders), newest first. Unwraps the
/// repository's `Result` stream into an [AsyncValue].
final adminOrdersProvider = StreamProvider<List<Order>>((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.watchAllOrders().map(
        (result) => result.fold(
          onSuccess: (orders) => orders,
          onFailure: (failure) => throw failure,
        ),
      );
});
