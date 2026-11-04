import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/product_model.dart';

/// Service layer for Product CRUD and querying operations on Cloud Firestore.
class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.productsCollection);

  /// Streams all products with safe in-memory sorting without requiring composite indexes.
  Stream<List<ProductModel>> streamProducts({
    String? categoryId,
    bool onlyActive = false,
  }) {
    return _collection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .where((p) {
            if (onlyActive && !p.isActive) return false;
            if (categoryId != null &&
                categoryId.isNotEmpty &&
                categoryId != 'all' &&
                p.categoryId != categoryId) {
              return false;
            }
            return true;
          })
          .toList();

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// One-time fetch of products.
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    bool onlyActive = false,
  }) async {
    final snapshot = await _collection.get();
    final list = snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .where((p) {
          if (onlyActive && !p.isActive) return false;
          if (categoryId != null &&
              categoryId.isNotEmpty &&
              categoryId != 'all' &&
              p.categoryId != categoryId) {
            return false;
          }
          return true;
        })
        .toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Fetches a single product by ID.
  Future<ProductModel?> getProductById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return ProductModel.fromFirestore(doc);
  }

  /// Finds a product by its barcode.
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    final snapshot = await _collection
        .where('barcode', isEqualTo: clean)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ProductModel.fromFirestore(snapshot.docs.first);
  }

  /// Checks if a barcode is already used by another product.
  Future<bool> isBarcodeExists(String barcode, {String? excludeId}) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;

    final snapshot = await _collection
        .where('barcode', isEqualTo: clean)
        .limit(2)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      return true;
    }
    return false;
  }

  /// Checks if a product code is already in use.
  Future<bool> isCodeExists(String code, {String? excludeId}) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;

    final snapshot = await _collection
        .where('code', isEqualTo: clean)
        .limit(2)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      return true;
    }
    return false;
  }

  /// Generates a sequential suggestion for product code (e.g. PRD-0001).
  Future<String> generateNextProductCode() async {
    final snapshot = await _collection.get();
    final count = snapshot.docs.length + 1;
    return 'PRD-${count.toString().padLeft(4, '0')}';
  }

  /// Adds a new product document.
  Future<String> addProduct(ProductModel product) async {
    final now = DateTime.now();
    final data = product.toMap();
    data['createdAt'] = Timestamp.fromDate(now);
    data['updatedAt'] = Timestamp.fromDate(now);

    final docRef = await _collection.add(data);
    return docRef.id;
  }

  /// Updates an existing product document.
  Future<void> updateProduct(ProductModel product) async {
    final data = product.toMap();
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _collection.doc(product.id).update(data);
  }

  /// Updates stock quantity of a product directly.
  Future<void> updateStock(String id, int newStock) async {
    await _collection.doc(id).update({
      'stock': newStock,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Toggles the active status of a product.
  Future<void> toggleProductStatus(String id, bool currentStatus) async {
    await _collection.doc(id).update({
      'isActive': !currentStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes a product by ID.
  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
  }
}
