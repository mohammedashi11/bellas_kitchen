import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/features/admin/presentation/admin_order_view.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/order_transition.dart';

void main() {
  // ── Transition validation ──────────────────────────────────────────────────
  group('validateTransition', () {
    test('legal transitions return null', () {
      expect(validateTransition(OrderStatus.pending, OrderStatus.accepted),
          isNull);
      expect(validateTransition(OrderStatus.pending, OrderStatus.cancelled),
          isNull);
      expect(validateTransition(OrderStatus.accepted, OrderStatus.preparing),
          isNull);
      expect(validateTransition(OrderStatus.preparing, OrderStatus.ready),
          isNull);
      expect(validateTransition(OrderStatus.ready, OrderStatus.delivered),
          isNull);
    });

    test('illegal transitions return a ValidationFailure', () {
      // Backwards.
      expect(validateTransition(OrderStatus.delivered, OrderStatus.pending),
          isA<ValidationFailure>());
      // Skipping ahead.
      expect(validateTransition(OrderStatus.pending, OrderStatus.delivered),
          isA<ValidationFailure>());
      // From a terminal state.
      expect(validateTransition(OrderStatus.cancelled, OrderStatus.pending),
          isA<ValidationFailure>());
      expect(validateTransition(OrderStatus.delivered, OrderStatus.ready),
          isA<ValidationFailure>());
    });
  });

  // ── Forward status derivation ──────────────────────────────────────────────
  group('forwardStatus', () {
    test('advances one step along the happy path', () {
      expect(forwardStatus(OrderStatus.pending), OrderStatus.accepted);
      expect(forwardStatus(OrderStatus.accepted), OrderStatus.preparing);
      expect(forwardStatus(OrderStatus.preparing), OrderStatus.ready);
      expect(forwardStatus(OrderStatus.ready), OrderStatus.delivered);
    });

    test('terminal statuses have no forward status', () {
      expect(forwardStatus(OrderStatus.delivered), isNull);
      expect(forwardStatus(OrderStatus.cancelled), isNull);
    });

    test('never returns cancelled (only the forward path)', () {
      for (final s in OrderStatus.values) {
        expect(forwardStatus(s), isNot(OrderStatus.cancelled));
      }
    });
  });

  group('markAsLabel', () {
    test('title-cases the enum name', () {
      expect(markAsLabel(OrderStatus.preparing), 'Mark as Preparing');
      expect(markAsLabel(OrderStatus.ready), 'Mark as Ready');
      expect(markAsLabel(OrderStatus.delivered), 'Mark as Delivered');
      expect(markAsLabel(OrderStatus.accepted), 'Mark as Accepted');
    });
  });

  // ── Tab ↔ status grouping ──────────────────────────────────────────────────
  group('AdminOrderTab grouping', () {
    test('each tab maps to the expected statuses', () {
      expect(AdminOrderTab.incoming.statuses, {OrderStatus.pending});
      expect(AdminOrderTab.preparing.statuses,
          {OrderStatus.accepted, OrderStatus.preparing});
      expect(AdminOrderTab.ready.statuses, {OrderStatus.ready});
      expect(AdminOrderTab.completed.statuses,
          {OrderStatus.delivered, OrderStatus.cancelled});
    });

    test('orderInTab matches only the tab that owns the status', () {
      expect(orderInTab(OrderStatus.pending, AdminOrderTab.incoming), isTrue);
      expect(orderInTab(OrderStatus.preparing, AdminOrderTab.preparing), isTrue);
      expect(orderInTab(OrderStatus.delivered, AdminOrderTab.completed), isTrue);
      expect(orderInTab(OrderStatus.pending, AdminOrderTab.completed), isFalse);
    });

    test('every OrderStatus belongs to exactly one tab', () {
      for (final status in OrderStatus.values) {
        final owning = AdminOrderTab.values
            .where((t) => t.statuses.contains(status))
            .toList();
        expect(owning.length, 1, reason: '$status should map to one tab');
      }
    });
  });

  // ── Display helpers ────────────────────────────────────────────────────────
  group('orderNumber', () {
    test('uses the last 4 chars, uppercased', () {
      expect(orderNumber('abcd1234'), '#BK-1234');
      expect(orderNumber('xY9z'), '#BK-XY9Z');
    });
    test('short/empty ids degrade gracefully', () {
      expect(orderNumber(''), '#BK-0000');
      expect(orderNumber('ab'), '#BK-AB');
    });
  });

  group('customerLabel', () {
    test('empty userId → Guest', () {
      expect(customerLabel(''), 'Guest');
    });
    test('non-empty → Customer + first 6 uid chars (no Firestore read)', () {
      expect(customerLabel('abc123xyz789'), 'Customer ABC123');
      expect(customerLabel('ab'), 'Customer AB');
    });
  });

  group('relativeTime', () {
    final now = DateTime.utc(2024, 1, 1, 12, 0, 0);
    test('under a minute → Just now', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 10)), now: now),
          'Just now');
    });
    test('minutes / hours / days', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 3)), now: now),
          '3 min ago');
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now: now),
          '2 hr ago');
      expect(relativeTime(now.subtract(const Duration(days: 1)), now: now),
          '1 day ago');
      expect(relativeTime(now.subtract(const Duration(days: 3)), now: now),
          '3 days ago');
    });
  });
}
