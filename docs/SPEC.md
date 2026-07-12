# Bella's Kitchen — Master Spec

Canonical reference for domain entities, the Firestore schema, and cross-cutting
patterns. All future features build on this. When you change an entity or a
document shape, update this file in the same change.

**Layering rules**
- **Domain** (`features/*/domain/entities`): pure Dart entities. Zero Flutter /
  Firebase imports.
- **Data** (`features/*/data/models`): `*Model` classes `extend` their entity and
  add `fromMap` / `toFirestore` (Firestore serialisation lives here only).
- Repositories return `Result<T>` (see [Error pattern](#error-pattern)).

---

## Error pattern

`Result<S>` — `lib/core/utils/result.dart`

```
sealed class Result<S>
  Success<S>(S data)
  Failure<S>(AppFailure failure)   // typed failure, not a raw String
```

Extensions: `isSuccess`, `isFailure`, `dataOrNull`, `errorOrNull` (→ `AppFailure?`),
`fold({onSuccess, onFailure})`.

`AppFailure` — `lib/core/error/app_failure.dart` (sealed, pure Dart, each carries
`String message`):

| Subtype | Meaning |
|---|---|
| `NetworkFailure` | Backend unreachable (offline, timeout, DNS). |
| `ServerFailure` | Backend reached, responded with an error (5xx / internal). |
| `NotFoundFailure` | Requested resource does not exist. |
| `UnauthorizedFailure` | Not authenticated / lacks permission. |
| `ValidationFailure` | Input failed validation. |
| `UnknownFailure` | Anything unmapped. |

Data layers map low-level exceptions into an `AppFailure` and wrap it in
`Failure<S>`. The old `lib/core/errors/failures.dart` has been **deleted**.

> Current state: `FirestoreMenuRepository` never emits `Failure` today — on any
> error it falls back to mock data and returns `Success` (dev-only behavior).
> The typed `Failure<AppFailure>` channel exists for the repositories added next
> (Order, User, Auth).

---

## Firestore collections

Collection names and field keys are centralised in `lib/core/constants/app_constants.dart`.
Timestamps are Firestore `Timestamp`; `createdAt` / `updatedAt` are written with
`FieldValue.serverTimestamp()` on create.

### `menu_items`

Document id = auto / menu item id.

| Field | Type | Notes |
|---|---|---|
| `name` | String | |
| `description` | String | |
| `price` | number (double) | |
| `imageUrl` | String | |
| `category` | String | One of [storable categories](#categories); never `'All'`. |
| `isBestSeller` | bool | default `false` |
| `isAvailable` | bool | default `true`; query filters `== true` |
| `createdAt` | Timestamp | **queried** (`orderBy` asc). Written via `serverTimestamp()`. Missing → epoch on read. |

Query: `where(isAvailable == true).orderBy(createdAt asc)`, plus optional
`where(category == X)` when a real category is selected.

### `orders`

Document id = auto order id. Line items are a **nested array of maps** (`items`),
not a subcollection.

| Field | Type | Notes |
|---|---|---|
| `userId` | String | Firebase Auth UID of the owner. |
| `items` | array\<map\> | Each map = an `OrderItem` (below). Frozen at checkout. |
| `subtotal` | number (double) | Sum of line totals. |
| `deliveryFee` | number (double) | |
| `tax` | number (double) | |
| `total` | number (double) | `subtotal + deliveryFee + tax`. |
| `status` | String | `OrderStatus.storageKey` (enum name). |
| `payment` | String | `PaymentMethod.storageKey` (enum name). |
| `deliveryAddress` | String | |
| `createdAt` | Timestamp | `serverTimestamp()` on create. |
| `updatedAt` | Timestamp | `serverTimestamp()` on every write. |

`items[]` element (`OrderItem`):

| Field | Type | Notes |
|---|---|---|
| `menuItemId` | String | Link back to the (possibly since-changed) menu item. |
| `name` | String | Frozen snapshot. |
| `price` | number (double) | Frozen unit price at checkout. |
| `quantity` | number (int) | |

### `users`

Document id = Firebase Auth `uid` (not duplicated in the body).

| Field | Type | Notes |
|---|---|---|
| `phoneNumber` | String | |
| `displayName` | String? | nullable |
| `savedAddresses` | array\<String\> | default `[]` |
| `createdAt` | Timestamp | `serverTimestamp()` on create. |
| `role` | String? | **Absent for customers/anonymous** (implicitly `customer`); `'admin'` for admins. Set **only** via the Firebase console. The app writes `role` **only when admin** (`AppUserModel.toFirestore`), so customer/anon creation omits it and no write downgrades an admin by omission. Read defensively: missing/unknown ⇒ `customer` (never accidentally admin). |

> **Role gating:** the app-side admin check (email/password login reads this field; a non-admin is signed straight back out) is **UX only**. Real enforcement is Firestore security rules (a later step).

---

## Domain entities

| Entity | File | Fields |
|---|---|---|
| `MenuItem` | `features/menu/domain/entities/menu_item.dart` | `id, name, description, price:double, imageUrl, category, isBestSeller, isAvailable, createdAt:DateTime`. `==`/`hashCode` on `id`. Not const (holds `DateTime`). |
| `CartItem` | `features/cart/domain/entities/cart_item.dart` | `item:MenuItem, quantity:int`; derived `lineTotal`. In-memory only (not persisted). |
| `OrderItem` | `features/order/domain/entities/order_item.dart` | `menuItemId, name, price:double, quantity:int`; derived `lineTotal`. **Frozen snapshot** — no live `MenuItem` ref. |
| `Order` | `features/order/domain/entities/order.dart` | see `orders` schema; derived `itemCount`. |
| `OrderStatus` | `features/order/domain/entities/order_status.dart` | enum (below). |
| `PaymentMethod` | `features/order/domain/entities/payment_method.dart` | enum `card, cash`; `displayLabel`, `storageKey`, `fromStorage`. |
| `AppUser` | `features/user/domain/entities/app_user.dart` | `uid, phoneNumber, displayName?, savedAddresses:List<String>, createdAt:DateTime, role:UserRole`. `isAdmin` getter. |
| `UserRole` | `features/user/domain/entities/user_role.dart` | enum `customer, admin`; `storageKey`, `fromStorage` (defensive: only `'admin'` ⇒ admin). |

Data models: `MenuItemModel`, `OrderModel`, `OrderItemModel`, `AppUserModel`.
No repositories exist yet for Order or User — those arrive with the Auth and
Order features.

> **Naming caveat:** `cloud_firestore` exports its own `Order` (an asc/desc
> enum). Any data-layer file that imports both `cloud_firestore` and our `Order`
> must import Firestore with `show Timestamp, FieldValue` (as `order_model.dart`
> does) to avoid the clash.

---

## OrderStatus transitions

Enum: `pending, accepted, preparing, ready, delivered, cancelled`.

Happy path: `pending → accepted → preparing → ready → delivered`.
Any non-terminal status may go to `cancelled`. `delivered` and `cancelled` are
terminal.

| From | Allowed next |
|---|---|
| `pending` | `accepted`, `cancelled` |
| `accepted` | `preparing`, `cancelled` |
| `preparing` | `ready`, `cancelled` |
| `ready` | `delivered`, `cancelled` |
| `delivered` | — (terminal) |
| `cancelled` | — (terminal) |

Helpers on the enum: `displayLabel`, `storageKey`, `allowedNextStatuses`,
`canTransitionTo(next)`, `isTerminal`, `fromStorage(key)`.

---

## <a name="categories"></a>Categories

Single source of truth: `AppConstants` in `lib/core/constants/app_constants.dart`.

- `menuCategories` — tab-bar list, includes the `'All'` sentinel at the front.
- `storableCategories` — the values that may be stored on a `MenuItem`
  (`Burgers, Pizza, Sides, Desserts, Drinks`).
- `categoryAll = 'All'` — **UI-only sentinel**. Means "no category filter". Never
  written to Firestore, never stored on a `MenuItem`.
- `defaultCategory = 'Other'` — **defensive, read-only fallback** applied when a
  document's `category` is missing or malformed on read. Deliberately **not** in
  `storableCategories` and **not** a selectable tab, and **never written** to
  Firestore. It is an out-of-band bucket that signals bad data: such an item is
  excluded from every real category tab (it only appears under `All`, tagged
  `'Other'`) instead of masquerading as a legitimate item under a real tab.
  Contrast with mapping bad data to a real category (e.g. `'Sides'`), which would
  camouflage it.
