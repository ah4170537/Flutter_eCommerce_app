import 'package:cloud_firestore/cloud_firestore.dart';

/// Moves a guest's cart into a newly logged-in/registered user's cart.
///
/// IMPORTANT — this must be done in two phases because Firestore Security
/// Rules only allow a user to read/write their OWN cart
/// (`cart/{uid}/user_cart`, checked against `request.auth.uid`). The
/// moment `signIn()`/`signUp()` succeeds, the Firebase session switches
/// from the guest's anonymous uid to the new account's uid — so trying to
/// read/delete the guest's cart AFTER that point gets rejected as
/// `permission-denied`, since the app is no longer authenticated as the
/// guest.
///
/// The fix: capture and clear the guest cart BEFORE calling signIn/signUp
/// (while still authenticated as the guest), then write those items into
/// the new account's cart AFTER signing in (while authenticated as the
/// new user, writing to their own cart).
class CartMergeHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// PHASE 1 — call this BEFORE signIn()/signUp(), while still
  /// authenticated as the guest.
  ///
  /// Reads every item from the guest's cart, deletes them (guest is
  /// allowed to delete their own cart), and returns the item data so it
  /// can be written into the new account's cart afterward.
  Future<List<Map<String, dynamic>>> captureAndClearGuestCart(
    String guestUserId,
  ) async {
    if (guestUserId.isEmpty) return [];

    final guestCartRef = _db
        .collection('cart')
        .doc(guestUserId)
        .collection('user_cart');

    final guestCartSnapshot = await guestCartRef.get();

    if (guestCartSnapshot.docs.isEmpty) return [];

    final List<Map<String, dynamic>> capturedItems = [];
    final batch = _db.batch();

    for (final guestDoc in guestCartSnapshot.docs) {
      // Keep the productId alongside the rest of the item's data so
      // Phase 2 knows which document to write to in the new cart.
      capturedItems.add({
        'productId': guestDoc.id,
        ...guestDoc.data(),
      });
      batch.delete(guestCartRef.doc(guestDoc.id));
    }

    await batch.commit();
    return capturedItems;
  }

  /// PHASE 2 — call this AFTER signIn()/signUp() succeeds, now
  /// authenticated as the new (real) user.
  ///
  /// Writes the previously-captured guest items into the new user's own
  /// cart. If a product already exists there, quantities are summed
  /// instead of overwritten.
  Future<void> mergeItemsIntoUserCart({
    required String newUserId,
    required List<Map<String, dynamic>> guestItems,
  }) async {
    if (guestItems.isEmpty || newUserId.isEmpty) return;

    final newUserCartRef = _db
        .collection('cart')
        .doc(newUserId)
        .collection('user_cart');

    final batch = _db.batch();

    for (final item in guestItems) {
      final String productId = item['productId'];
      final num guestQuantity = item['quantity'] ?? 1;

      final existingDoc = await newUserCartRef.doc(productId).get();

      if (existingDoc.exists) {
        final existingData = existingDoc.data() as Map<String, dynamic>;
        final num existingQuantity = existingData['quantity'] ?? 1;

        batch.update(newUserCartRef.doc(productId), {
          'quantity': existingQuantity + guestQuantity,
        });
      } else {
        final Map<String, dynamic> itemData = Map.from(item)
          ..remove('productId'); // don't store productId as a field too
        batch.set(newUserCartRef.doc(productId), itemData);
      }
    }

    await batch.commit();
  }
}