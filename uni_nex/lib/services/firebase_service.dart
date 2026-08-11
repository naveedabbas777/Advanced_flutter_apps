import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../config/app_config.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String eventsCollection = 'events';
  static const String usersCollection = 'users';
  static const String navigationCollection = 'navigation';
  static const String lostFoundCollection = 'lost_found_items';

  // Generic CRUD operations
  Future<DocumentReference<Map<String, dynamic>>> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    if (!AppConfig.enableFirebase) {
      throw Exception('Firebase is disabled in config');
    }
    return await _firestore.collection(collection).add(data);
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    if (!AppConfig.enableFirebase) {
      throw Exception('Firebase is disabled in config');
    }
    await _firestore.collection(collection).doc(documentId).update(data);
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    if (!AppConfig.enableFirebase) {
      throw Exception('Firebase is disabled in config');
    }
    await _firestore.collection(collection).doc(documentId).delete();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String collection,
    String documentId,
  ) async {
    if (!AppConfig.enableFirebase) {
      throw Exception('Firebase is disabled in config');
    }
    return await _firestore.collection(collection).doc(documentId).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCollectionStream(
    String collection, {
    int? limit,
    String? orderBy,
    bool descending = false,
  }) {
    if (!AppConfig.enableFirebase) {
      // Return empty stream if Firebase is disabled
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  // Events specific operations
  Future<String> addEvent(EventModel event) async {
    final docRef = await addDocument(eventsCollection, event.toFirestore());
    return docRef.id;
  }

  Future<void> updateEvent(String eventId, EventModel event) async {
    await updateDocument(eventsCollection, eventId, event.toFirestore());
  }

  Future<void> deleteEvent(String eventId) async {
    await deleteDocument(eventsCollection, eventId);
  }

  Stream<List<EventModel>> getEventsStream() {
    return getCollectionStream(
      eventsCollection,
      orderBy: 'createdAt',
      descending: true,
    ).map((snapshot) {
      return snapshot.docs.map((doc) {
        return EventModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Navigation/Waypoints operations
  Future<String> addWaypoint(Map<String, dynamic> waypoint) async {
    final docRef = await addDocument(navigationCollection, waypoint);
    return docRef.id;
  }

  Stream<List<Map<String, dynamic>>> getWaypointsStream() {
    return getCollectionStream(navigationCollection).map((snapshot) {
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  // Utility methods
  Future<bool> isConnected() async {
    try {
      await _firestore.collection('test').doc('test').get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Batch operations
  Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    if (!AppConfig.enableFirebase) return;

    final batch = _firestore.batch();

    for (final operation in operations) {
      final type = operation['type'];
      final collection = operation['collection'];
      final data = operation['data'];

      switch (type) {
        case 'add':
          final docRef = _firestore.collection(collection).doc();
          batch.set(docRef, data);
          break;
        case 'update':
          final docId = operation['documentId'];
          batch.update(_firestore.collection(collection).doc(docId), data);
          break;
        case 'delete':
          final docId = operation['documentId'];
          batch.delete(_firestore.collection(collection).doc(docId));
          break;
      }
    }

    await batch.commit();
  }
}
