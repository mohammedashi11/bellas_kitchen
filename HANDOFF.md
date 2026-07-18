# HANDOFF — Bella's Kitchen

Single-restaurant food-ordering app. Flutter + Riverpod + Clean Architecture + Firebase.
Portfolio piece. Firebase project: `bellaskitchen-cefcb` (Spark / free plan).

---

## Current state

The app is **functionally complete and running on a real device + web.** Full loop verified end-to-end:
customer orders on mobile → admin advances status on web → customer tracking updates live via Firestore streams.

- `flutter analyze`: clean
- `flutter test`: 116 passing
- Latest work: customer Profile / Order History (committed), plus a pending fix pass (guest log-out + search).

**Two platforms, one codebase, separated by route:**
- **Customer app** → mobile. Orange theme.
- **Admin panel** → web only, at `/#/admin/login`. Navy/blue theme. No admin entry point exists in the customer app (path separation is part of the security model).

---

## Architecture decisions (locked)

- **Clean Architecture per feature**: `domain` (pure Dart entities), `data` (models + Firestore repos), `presentation` (Riverpod + screens). Entities never import Flutter/Firebase.
- **`Result<S>` + sealed `AppFailure`** for all repository returns. No raw strings, no silent catches. Errors surface as typed failures; empty is empty, never mock.
- **`OrderItem` is a frozen snapshot** — captures name/price/qty at checkout, not a live `MenuItem` ref, so old orders keep their original price if the menu changes.
- **Admin identity = `role: 'admin'` field on `users/{uid}`** (not custom claims — those need Blaze + Cloud Functions). Enforced server-side in Firestore rules via `isAdmin()` helper, not just UI.
- **Anonymous Auth for guests** — every order carries a real `request.auth.uid`, so security rules stay strict (no `if true` on orders) without a login wall at checkout.
- **Client-side filtering over composite indexes** — menu and user-orders queries use a single `orderBy`/equality filter and filter the rest in Dart, avoiding composite indexes entirely (menu-sized data).
- **Real Firestore is the single source of truth** — the dev-only mock fallback was removed; it had been masking a `failed-precondition` index error.
- **Firebase Storage gated off** (`storageUploadEnabled = false`) — Storage now requires Blaze. Upload code is built and intact; menu images use pasted URLs (Unsplash) as the working path. One flag flip enables real upload later.
- **Live status loop**: admin `updateOrderStatus` → Firestore → customer `watchOrder` stream. Status transitions validated against `OrderStatus.allowedNextStatuses` at both app and DB layers.

---

## Done

**Customer:** Home/Menu (real Firestore data), Item Detail (add-ons display-only), Cart/Checkout (writes real order), Order Tracking (4-node customer stepper, live), Auth (phone/OTP + anonymous), Profile / Order History (sign-out, index-free history query).

**Admin (web):** Login (email/password + role gate), unified shell (Home/Orders/Menu/Settings via IndexedStack), Dashboard (client-side aggregation, no fabricated trend %), Live Orders (accept/reject + status advance), Menu Management (full CRUD + write-side category validation guard).

**Infra:** Firestore security rules (auth-gated, admin-role-aware) published. Storage rules written (unpublished — Storage not enabled). Anonymous + Phone + Email/Password providers enabled. Firebase config gitignored.

---

## Remaining

**In-flight fix pass** (prompt already sent):
- Guest "Log Out" bug — a guest logging out gets a new uid and loses order history. Fix: guests see "Sign In" instead of "Log Out".
- Home search bar — currently non-functional; wire client-side menu filtering.

**Intentionally deferred (not bugs — conscious scope calls):**
- Cancel Order — needs a guarded order-update write path (build alongside admin, if ever).
- Add-on modeling into cart/order (currently display-only preview).
- Inert "coming soon" rows: Saved Addresses, Notifications, Help & Support, Contact Restaurant, admin Settings/notifications bell.
- Push notifications (FCM) — needs Blaze + Cloud Functions.
- Real image upload — needs Blaze (code ready behind the flag).
- Account linking (upgrade anonymous → phone keeping uid + history).

**Portfolio polish:**
- **README** — highest-value remaining item. Currently default/empty.
- Optional refactors from the structural audit: composition root, cart↔order coupling.

---

## Key files / layout

```
lib/
  core/
    error/app_failure.dart          # sealed AppFailure + subtypes
    utils/result.dart               # Result<S> carrying AppFailure
    constants/app_constants.dart    # routes, storableCategories, flags (storageUploadEnabled, enforceAuth)
  features/
    menu/                           # customer menu (real Firestore read, client-side filter)
    order/
      domain/entities/             # Order, OrderItem (frozen), OrderStatus, PaymentMethod
      data/                        # OrderModel, FirestoreOrderRepository (placeOrder, watchOrder, watchUserOrders, watchAllOrders, updateOrderStatus)
      presentation/                # tracking, order history, shared order_display helpers
    cart/                          # CartNotifier, checkout, PlaceOrderUseCase
    user/                          # AppUser (+ role, isAdmin), AppUserModel
    admin/
      presentation/screens/        # admin shell, dashboard, live orders, menu mgmt, login
      ...dashboard_stats.dart      # pure client-side aggregation
    auth/                          # phone/OTP, anonymous, email/password, role gate, router guard
docs/SPEC.md                       # canonical schema, entities, transitions, error pattern
```

**Firestore collections:** `menu_items`, `orders`, `users`.

**Git:** author identity set to the project owner. Firebase config files (`google-services.json`, `firebase_options.dart`) are gitignored (client-side config, not high-severity secrets; Firestore rules are the real protection). A `backup-before-rewrite` branch exists.

---

## Gotchas for the next session

- Menu is empty until items are added via the admin panel (mock data is gone). Add 5–6 items with Unsplash URLs to populate.
- Admin access only via `localhost:PORT/#/admin/login` on `flutter run -d chrome`. Admin user + `role:'admin'` doc must exist in Firestore.
- `flutter run` is used sparingly (visual checks done manually in batches); `analyze` + `test` after every change.
- Storage is NOT enabled (needs Blaze) — keep image input as URL paste.
