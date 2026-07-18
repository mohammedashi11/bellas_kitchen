# Bella's Kitchen 🍔

A production-style, single-restaurant food-ordering app built with **Flutter + Riverpod + Clean Architecture + Firebase**. Customers order on mobile; the restaurant runs a separate web admin panel. Order status flows live between the two over Firestore streams.

Built as a portfolio piece to demonstrate full-stack mobile development end-to-end — not just UI, but architecture, real backend integration, role-based access, and security.

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black">
  <img alt="State" src="https://img.shields.io/badge/State-Riverpod-3E63DD">
  <img alt="Architecture" src="https://img.shields.io/badge/Architecture-Clean-4CAF50">
  <img alt="Tests" src="https://img.shields.io/badge/tests-158%20passing-brightgreen">
</p>

---

## What it does

**Two apps, one codebase, separated by route.**

| | Customer app (mobile) | Admin panel (web) |
|---|---|---|
| **Theme** | Warm orange | Navy / blue, minimal |
| **Auth** | Phone/OTP + anonymous guest | Email/password + `role: admin` gate |
| **Menu** | Browse categories, search, item detail | Full CRUD, category validation, availability toggle |
| **Orders** | Cart → checkout → live tracking, cancel while pending | Live incoming orders, accept/reject, advance status |
| **Add-ons** | Pick extras on an item → priced into the cart line → frozen onto the order | Define add-ons (name + price) per menu item |
| **Tracking** | 4-stage stepper, updates in real time | One-tap status transitions |
| **Profile** | Order history, sign-in prompt for guests | Client-side dashboard (orders, revenue, best seller) |

There is **no admin entry point inside the customer app** — the admin panel only exists at `/#/admin/login` on web. Path separation is part of the security model, not just a UI choice.

The full loop is verified end-to-end: customer orders on a real device → admin advances the order on web → the customer's tracking screen updates live.

---

## Screenshots

> Add real screenshots here. Customer screens go in `docs/screenshots/customer/`, admin in `docs/screenshots/admin/`.

| Home / Menu | Item Detail | Cart | Order Tracking |
|---|---|---|---|
| _tbd_ | _tbd_ | _tbd_ | _tbd_ |

| Admin Login | Dashboard | Live Orders | Menu Management |
|---|---|---|---|
| _tbd_ | _tbd_ | _tbd_ | _tbd_ |

---

## Architecture

**Clean Architecture, per feature.** Every feature is split into three layers:

- `domain` — pure Dart entities and use cases. Never imports Flutter or Firebase.
- `data` — models + Firestore repositories.
- `presentation` — Riverpod providers + screens.

The domain layer having zero framework dependencies is what makes the business logic testable in plain Dart and portable if the backend ever changes.

### Decisions worth calling out

- **`Result<S>` + sealed `AppFailure`** for every repository return. No raw error strings, no silently swallowed exceptions. Errors surface as typed failures, and *empty is empty* — never faked with mock data. (An earlier dev-only mock fallback was removed precisely because it had been masking a real `failed-precondition` index error.)
- **`OrderItem` is a frozen snapshot.** It captures name/price/quantity at checkout instead of holding a live `MenuItem` reference — so past orders keep their original prices even if the menu changes later.
- **Admin identity via `role: 'admin'` on `users/{uid}`**, enforced *server-side* in Firestore rules through an `isAdmin()` helper — not just hidden in the UI. (Custom claims were skipped intentionally: they require Blaze + Cloud Functions.)
- **Anonymous Auth for guests.** Every order carries a real `request.auth.uid`, so security rules stay strict without forcing a login wall at checkout.
- **Client-side filtering over composite indexes.** Menu and user-order queries use a single `orderBy`/equality filter and refine the rest in Dart — avoiding composite indexes entirely for menu-sized data.
- **Real Firestore is the single source of truth.** No mock layer in the running app.
- **Validated status transitions.** `OrderStatus.allowedNextStatuses` is enforced at *both* the app layer and the DB layer, so an order can't jump to an invalid state.

---

## Tech stack

- **Flutter** (Android / iOS / Web)
- **Riverpod** — state management
- **go_router** — routing + admin route guard
- **Firebase** — Auth (Phone, Anonymous, Email/Password), Cloud Firestore
- **Firestore Security Rules** — auth-gated, admin-role-aware, published

> Firebase Storage is intentionally **gated off** (`storageUploadEnabled = false`) because Storage now requires the Blaze plan. The upload code is fully built and intact — menu images currently use pasted image URLs. Flipping one flag enables real uploads.

---

## Project structure

```
lib/
  core/
    error/app_failure.dart        # sealed AppFailure + subtypes
    utils/result.dart             # Result<S> carrying AppFailure
    constants/app_constants.dart  # routes, categories, feature flags
  features/
    menu/                         # customer menu (real Firestore, client-side filter + search)
    order/
      domain/entities/            # Order, OrderItem (frozen), OrderStatus, PaymentMethod
      data/                       # OrderModel, FirestoreOrderRepository
      presentation/               # tracking, order history, shared display helpers
    cart/                         # CartNotifier, checkout, PlaceOrderUseCase
    user/                         # AppUser (+ role, isAdmin), AppUserModel
    admin/
      presentation/screens/       # shell, dashboard, live orders, menu mgmt, login
    auth/                         # phone/OTP, anonymous, email/password, role gate, router guard
docs/SPEC.md                      # canonical schema, entities, transitions, error pattern
```

**Firestore collections:** `menu_items`, `orders`, `users`.

---

## Getting started

### Prerequisites
- Flutter SDK (3.x)
- A Firebase project on the Spark (free) plan is enough
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### Setup

```bash
# 1. Clone + install deps
git clone <your-repo-url>
cd bellas_kitchen
flutter pub get

# 2. Connect your own Firebase project
#    (firebase_options.dart and google-services.json are gitignored)
flutterfire configure

# 3. Enable these Auth providers in the Firebase console:
#    Anonymous, Phone, Email/Password

# 4. Publish the Firestore security rules from this repo
```

### Run

```bash
# Customer app (mobile)
flutter run

# Admin panel (web only) — then open http://localhost:PORT/#/admin/login
flutter run -d chrome
```

> **First-run note:** the menu is empty until items are added through the admin panel — there is no mock seed data. Create an admin user in the console, add a `role: 'admin'` field to that user's `users/{uid}` doc, then add a few menu items (Unsplash image URLs work well).

---

## Testing

```bash
flutter analyze   # clean, 0 issues
flutter test      # 158 passing
```

Because the domain layer is framework-free and repositories return typed `Result`s, business logic is covered with fast plain-Dart tests — no emulator required for the core suites.

---

## Roadmap

These are **conscious scope calls**, not missing pieces — documented here to show the boundary was deliberate:

- **Push notifications (FCM)** — needs Blaze + Cloud Functions.
- **Real image upload** — code is ready behind the `storageUploadEnabled` flag; needs Blaze.
- **Account linking** — upgrade an anonymous guest to a phone account while preserving the same UID and order history.

---

## License

MIT — feel free to learn from it.
