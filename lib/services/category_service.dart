import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/category_model.dart';

/// Service layer for Category CRUD operations on Cloud Firestore.
class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.categoriesCollection);

  /// Streams all categories, optionally filtered by active status.
  Stream<List<CategoryModel>> streamCategories({bool onlyActive = false}) {
    return _collection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .where((c) => !onlyActive || c.isActive)
          .toList();
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Fetches a one-time list of categories.
  Future<List<CategoryModel>> getCategories({bool onlyActive = false}) async {
    final snapshot = await _collection.get();
    final list = snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc))
        .where((c) => !onlyActive || c.isActive)
        .toList();
    list.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Fetches a category by its ID.
  Future<CategoryModel?> getCategoryById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return CategoryModel.fromFirestore(doc);
  }

  /// Checks if a category name already exists (case-insensitive check).
  Future<bool> isCategoryNameExists(String name, {String? excludeId}) async {
    final cleanName = name.trim().toLowerCase();
    final snapshot = await _collection.get();
    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final docName = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (docName == cleanName) {
        return true;
      }
    }
    return false;
  }

  /// Adds a new category document.
  Future<String> addCategory(CategoryModel category) async {
    final now = DateTime.now();
    final data = category.toMap();
    data['createdAt'] = Timestamp.fromDate(now);
    data['updatedAt'] = Timestamp.fromDate(now);

    final docRef = await _collection.add(data);
    return docRef.id;
  }

  /// Updates an existing category document.
  Future<void> updateCategory(CategoryModel category) async {
    final data = category.toMap();
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _collection.doc(category.id).update(data);
  }

  /// Toggles the active status of a category.
  Future<void> toggleCategoryStatus(String id, bool currentStatus) async {
    await _collection.doc(id).update({
      'isActive': !currentStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes a category by ID.
  Future<void> deleteCategory(String id) async {
    await _collection.doc(id).delete();
  }
}
