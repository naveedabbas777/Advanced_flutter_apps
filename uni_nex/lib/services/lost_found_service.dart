import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/lost_found_item_model.dart';

class LostFoundService {
  static final LostFoundService _instance = LostFoundService._internal();
  factory LostFoundService() => _instance;
  LostFoundService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collection = 'lost_found_items';

  // ─── Submit a found item (any signed-in user) ────────────────────────
  Future<String> submitFoundItem(LostFoundItem item) async {
    try {
      final docRef = await _firestore.collection(collection).add(
            item.copyWith(status: LostFoundStatus.pending).toFirestore(),
          );
      debugPrint('Lost & Found item submitted: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error submitting found item: $e');
      rethrow;
    }
  }

  // ─── Streams ─────────────────────────────────────────────────────────
  // NOTE: Queries that combine .where() + .orderBy() on different fields
  // require Firestore composite indexes. To avoid index-missing errors,
  // we fetch with .where() only and sort client-side.

  /// All items with status == approved (visible to all users)
  Stream<List<LostFoundItem>> getApprovedItemsStream() {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: LostFoundStatus.approved.name)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LostFoundItem.fromFirestore(doc.data(), doc.id))
          .toList();
      // Sort client-side: newest approved first
      items.sort((a, b) {
        final aDate = a.approvedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.approvedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  /// All items with status == pending (admin review queue)
  Stream<List<LostFoundItem>> getPendingItemsStream() {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: LostFoundStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LostFoundItem.fromFirestore(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  /// Items filtered by a given status (admin tabs)
  Stream<List<LostFoundItem>> getItemsByStatusStream(LostFoundStatus status) {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: status.name)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LostFoundItem.fromFirestore(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  /// All items regardless of status (admin overview)
  Stream<List<LostFoundItem>> getAllItemsStream() {
    return _firestore
        .collection(collection)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LostFoundItem.fromFirestore(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  /// Items submitted by a specific user
  Stream<List<LostFoundItem>> getMySubmittedItemsStream(String userId) {
    return _firestore
        .collection(collection)
        .where('finderUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LostFoundItem.fromFirestore(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  // ─── Admin Actions ───────────────────────────────────────────────────

  /// Approve a pending item
  Future<void> approveItem(String itemId, {String? adminNote}) async {
    try {
      await _firestore.collection(collection).doc(itemId).update({
        'status': LostFoundStatus.approved.name,
        'adminNote': adminNote,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Item $itemId approved');
    } catch (e) {
      debugPrint('Error approving item: $e');
      rethrow;
    }
  }

  /// Reject a pending item
  Future<void> rejectItem(String itemId, {String? adminNote}) async {
    try {
      await _firestore.collection(collection).doc(itemId).update({
        'status': LostFoundStatus.rejected.name,
        'adminNote': adminNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Item $itemId rejected');
    } catch (e) {
      debugPrint('Error rejecting item: $e');
      rethrow;
    }
  }

  /// Mark an item as claimed
  Future<void> markAsClaimed(String itemId, {String? claimedByUserId}) async {
    try {
      await _firestore.collection(collection).doc(itemId).update({
        'status': LostFoundStatus.claimed.name,
        'claimedByUserId': claimedByUserId,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Item $itemId marked as claimed');
    } catch (e) {
      debugPrint('Error marking item as claimed: $e');
      rethrow;
    }
  }

  /// Delete an item (admin only)
  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection(collection).doc(itemId).delete();
      debugPrint('Item $itemId deleted');
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  // ─── Counts (for badges / stats) ────────────────────────────────────

  Future<int> getPendingCount() async {
    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('status', isEqualTo: LostFoundStatus.pending.name)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending count: $e');
      return 0;
    }
  }

  Stream<int> getPendingCountStream() {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: LostFoundStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
