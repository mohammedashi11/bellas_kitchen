// App-wide string constants for Bella's Kitchen.
abstract final class AppConstants {
  // App info
  static const String appName = "Bella's Kitchen";
  static const String tagline = 'OPEN NOW';

  // Firestore collections
  static const String menuItemsCollection = 'menu_items';
  static const String ordersCollection = 'orders';
  static const String usersCollection = 'users';

  // Firestore field names — shared
  static const String fieldId = 'id';
  static const String fieldName = 'name';
  static const String fieldDescription = 'description';
  static const String fieldPrice = 'price';
  static const String fieldImageUrl = 'imageUrl';
  static const String fieldCategory = 'category';
  static const String fieldIsBestSeller = 'isBestSeller';
  static const String fieldIsAvailable = 'isAvailable';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';

  // Firestore field names — orders
  static const String fieldUserId = 'userId';
  static const String fieldItems = 'items';
  static const String fieldMenuItemId = 'menuItemId';
  static const String fieldQuantity = 'quantity';
  static const String fieldSubtotal = 'subtotal';
  static const String fieldDeliveryFee = 'deliveryFee';
  static const String fieldTax = 'tax';
  static const String fieldTotal = 'total';
  static const String fieldStatus = 'status';
  static const String fieldPayment = 'payment';
  static const String fieldDeliveryAddress = 'deliveryAddress';

  // Firestore field names — users
  static const String fieldUid = 'uid';
  static const String fieldPhoneNumber = 'phoneNumber';
  static const String fieldDisplayName = 'displayName';
  static const String fieldSavedAddresses = 'savedAddresses';
  static const String fieldRole = 'role'; // absent = customer; 'admin' = admin

  // Menu categories — single source of truth.
  //
  // [categoryAll] is a UI-ONLY sentinel for the "show everything" tab. It is
  // never written to Firestore and never stored on a MenuItem; the repository
  // treats it as "no category filter". Real, storable categories are
  // [storableCategories] (i.e. [menuCategories] without the sentinel).
  static const String categoryAll = 'All';

  /// Tab-bar categories, including the [categoryAll] UI sentinel at the front.
  static const List<String> menuCategories = [
    categoryAll,
    'Burgers',
    'Pizza',
    'Sides',
    'Desserts',
    'Drinks',
  ];

  /// The categories that may actually be stored on a MenuItem (the tab list
  /// minus the [categoryAll] sentinel).
  static const List<String> storableCategories = [
    'Burgers',
    'Pizza',
    'Sides',
    'Desserts',
    'Drinks',
  ];

  /// Defensive, READ-ONLY fallback for a menu item whose `category` field is
  /// missing or malformed. Deliberately NOT a member of [storableCategories]
  /// and never a selectable tab: mapping bad data to a real category would
  /// camouflage it under a legit tab, whereas an out-of-band `'Other'` bucket
  /// surfaces the problem visibly. Never write this value to Firestore.
  static const String defaultCategory = 'Other';

  // Route paths
  static const String routeHome = '/';
  static const String routeMenu = '/menu';
  static const String routeItem = '/item'; // detail: '/item/:id'
  static const String routeCart = '/cart';
  static const String routeOrders = '/orders';
  static const String routeProfile = '/profile';
  static const String routeAdmin = '/admin';
  static const String routeAdminLogin = '/admin/login';
  static const String routeAdminDashboard = '/admin/dashboard';
  static const String routePhoneEntry = '/auth/phone';
  static const String routeOtp = '/auth/otp';
  static const String routeOrder = '/order'; // confirmation/tracking: '/order/:id'

  // Auth
  // When true, unauthenticated users are redirected to phone sign-in before they
  // can use the app. Default false: the app opens straight to a usable, browsable
  // state (so the mock-menu demo works even when Firebase Auth is unreachable);
  // the full phone/OTP flow is still implemented and reachable. Flip to true for
  // production phone-gated access.
  static const bool enforceAuth = false;

  // Country dial code used by the phone-entry screen (single-country for now).
  static const String defaultDialCode = '+1';

  // Order pricing (demo values)
  static const double deliveryFee = 2.50; // flat delivery fee
  static const double taxRate = 0.09; // 9% sales tax

  // Feature gates
  // Firebase Storage requires the Blaze plan; the project stays on Spark, so
  // device image upload is gated OFF. The upload code (MenuImageUploader) is
  // built and ready — flip this to true once Storage is enabled.
  static const bool storageUploadEnabled = false;

  // Networking
  // Max time to wait on a Firestore read before falling back to mock data, so
  // an unreachable/slow backend never leaves the UI stuck on a loading spinner.
  static const Duration firestoreTimeout = Duration(seconds: 6);

  // Placeholder image
  static const String placeholderImageUrl =
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800';
}
