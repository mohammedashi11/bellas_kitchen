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

> All repositories (Menu, Order, Auth) emit typed `Failure<AppFailure>` on
> error. The menu's dev-only mock fallback has been REMOVED: `menu_items` in
> Firestore is the single source of truth — an empty collection reads as an
> empty list and errors surface as failures; the UI owns loading/empty/error
> states.

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
| `addOns` | array\<map\> | Customization options. Each map = an `AddOn` (below). Missing/absent ⇒ `[]`. |
| `createdAt` | Timestamp | **queried** (`orderBy` asc). Written via `serverTimestamp()`. Missing → epoch on read. |

Query: `where(isAvailable == true).orderBy(createdAt asc)`, plus optional
`where(category == X)` when a real category is selected.

`addOns[]` element (`AddOn` — the LIVE, admin-managed definition):

| Field | Type | Notes |
|---|---|---|
| `id` | String | Unique **within the item**. Cart line identity depends on it, so it must not change once customers have it. An entry read back without a usable `id` is **dropped**, never given a synthetic one. |
| `name` | String | |
| `price` | number (double) | Amount ADDED to the item's base price. `0` is valid and means a free preference (e.g. "No Onions"), which the UI renders as a switch rather than a priced checkbox — derived via `isFreePreference`, never stored. |

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
| `price` | number (double) | Frozen **base** unit price at checkout, excluding add-ons. |
| `quantity` | number (int) | |
| `addOns` | array\<map\> | Selected add-ons, frozen. Each map = an `OrderAddOn`: `name` + `price` **only** — deliberately no `id`, see below. Missing/absent ⇒ `[]`. |

The charged unit price is `price + Σ addOns[].price` (`OrderItem.unitPrice`);
`lineTotal` is that × `quantity`.

> **Why `OrderAddOn` is not `AddOn`.** An order line already freezes a *copy* of
> the menu item's name/price rather than referencing `MenuItem`; add-ons follow
> the identical rule. Storing only `name` + `price` means an admin renaming
> "Bacon" or changing its price can never rewrite what a past order shows or was
> charged, and it keeps the order domain free of any menu-layer import.

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
| `MenuItem` | `features/menu/domain/entities/menu_item.dart` | `id, name, description, price:double, imageUrl, category, isBestSeller, isAvailable, availableAddOns:List<AddOn>, createdAt:DateTime`. `==`/`hashCode` on `id`. Not const (holds `DateTime`). |
| `AddOn` | `features/menu/domain/entities/add_on.dart` | `id, name, price:double`; derived `isFreePreference` (`price == 0`). `==`/`hashCode` on `id`. The live, admin-managed definition. |
| `CartItem` | `features/cart/domain/entities/cart_item.dart` | `item:MenuItem, quantity:int, selectedAddOns:List<AddOn>`; derived `unitPrice`, `lineTotal`, `lineKey`. In-memory only (not persisted). |
| `OrderItem` | `features/order/domain/entities/order_item.dart` | `menuItemId, name, price:double, quantity:int, addOns:List<OrderAddOn>`; derived `unitPrice`, `lineTotal`. **Frozen snapshot** — no live `MenuItem`/`AddOn` ref. |
| `OrderAddOn` | `features/order/domain/entities/order_add_on.dart` | `name, price:double`. **Frozen snapshot** of a selected add-on; value equality on both fields. |
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
**`cancelled` is reachable ONLY from `pending`** — once the kitchen accepts an
order, food is committed and it can only move forward. `delivered` and
`cancelled` are terminal.

| From | Allowed next |
|---|---|
| `pending` | `accepted`, `cancelled` |
| `accepted` | `preparing` |
| `preparing` | `ready` |
| `ready` | `delivered` |
| `delivered` | — (terminal) |
| `cancelled` | — (terminal) |

Helpers on the enum: `displayLabel`, `storageKey`, `allowedNextStatuses`,
`canTransitionTo(next)`, `isTerminal`, `fromStorage(key)`.

`allowedNextStatuses` is the **single source of truth** for the cancel rule. It
is enforced at three layers, none of which restates the rule:

1. **Domain** — `validateTransition(from, to)` derives from `canTransitionTo`.
2. **Repository** — `cancelOrder(orderId)` and `updateOrderStatus(...)` share one
   private read-current → validate → write path in `FirestoreOrderRepository`,
   so both reject an illegal move identically (`ValidationFailure`, no write).
3. **Firestore rules** — the owner may update their own order to `cancelled`
   only when the *stored* status is `pending`, and only `status` + `updatedAt`
   may change (`affectedKeys().hasOnly`), so a "cancel" can't rewrite `total`,
   `items` or `userId`. Admin update rights are unchanged.

UI policy: `canCancelOrder(status)` (`order_stage.dart`) gates the tracking
screen's Cancel link to `pending`, which now matches the domain rule exactly.
Admin-side, REJECT is only offered on a `pending` order.

---

## Add-ons

Implemented end-to-end: **admin definition → customer selection → cart line →
frozen order snapshot.**

1. **Admin** defines add-ons on a menu item in the add/edit form (repeatable
   name + price rows). An existing add-on keeps the `id` it was saved with, so a
   rename never splits it from carts referencing it. Write validation lives in
   the same pure `validateMenuItemWrite` used for categories: non-blank name,
   **non-negative** price (zero is valid), no duplicate ids within an item.
2. **Customer** ticks add-ons on Item Detail. The "Add to Cart" price updates
   live and equals `CartItem.unitPrice × quantity` exactly — the button cannot
   show a figure the cart won't charge. Items with no add-ons omit the section.
3. **Cart** carries the selection on the line and shows the add-on-inclusive
   unit price. The existing subtotal / delivery / tax / total providers are
   untouched — they simply consume the new `lineTotal`.
4. **Order** freezes each selected add-on's name + price into `OrderAddOn` at
   checkout. Order Tracking's summary itemises them; Order History reaches the
   same view through its existing tap-through to the tracking route.

### Cart line identity

`CartItem.lineKey` decides whether an "add to cart" merges or starts a new line:

| Case | Result |
|---|---|
| Same item, **same** add-on selection | Merges — quantity increments |
| Same item, **different** add-on selection | **Separate line** |
| Same item + add-ons, chosen in a different **order** | Merges (ids are sorted) |
| Same item, with vs. without add-ons | Separate lines |

```
lineKey = addOns.isEmpty ? itemId : '$itemId#${sortedAddOnIds.join(",")}'
```

A line with **no** add-ons keys to the bare `itemId`. That is deliberate: the
cart map is keyed by `lineKey`, and this keeps every caller that removes or
decrements by menu item id behaving exactly as it did before add-ons existed.

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
