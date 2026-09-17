import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  static const String _baseKeyExpenses = 'expnz_expenses_taka_v2';
  static const String _baseKeyMonthlyDistribution = 'expnz_monthly_dist_v1';
  static const String _baseKeyBudget = 'expnz_budget_taka_v2';
  static const double defaultMonthlyBudget = 25000.0; // ৳25,000

  final _uuid = const Uuid();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? _userId;
  String? lastSyncError;

  void setUserId(String? uid) {
    _userId = uid;
    lastSyncError = null;
  }

  String? get userId => _userId;

  // Generate storage key isolated specifically to this user
  String _userKey(String baseKey) {
    if (_userId != null && _userId!.isNotEmpty) {
      return '${baseKey}_$_userId';
    }
    return '${baseKey}_guest';
  }

  // At launch the data will be 0, no table entry initially recorded
  List<ExpenseItem> getInitialSeedData({String prefix = 'initial-row'}) {
    return List.generate(
      5,
      (index) => ExpenseItem(
        id: '$prefix-${index + 1}',
        date: DateTime.now(),
        category: null,
        description: '',
        amount: 0.0,
        isPlaceholder: true,
        createdAt: DateTime.now().add(Duration(seconds: index)),
      ),
    );
  }

  Future<List<ExpenseItem>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyExpenses);

    // 1. If signed in, query user's dedicated Firestore document
    if (_userId != null && _userId!.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('expenses')
            .get();

        if (doc.exists && doc.data() != null && doc.data()!['items'] != null) {
          final List<dynamic> firestoreItems = doc.data()!['items'] as List<dynamic>;
          final parsed = firestoreItems
              .map((e) => ExpenseItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (parsed.isNotEmpty) {
            // Update this user's private local cache
            await prefs.setString(cacheKey, jsonEncode(parsed.map((e) => e.toMap()).toList()));
            return parsed;
          }
        } else {
          // Brand new user with no previous cloud records -> Start with fresh empty 0-data
          final initial = getInitialSeedData();
          await saveExpenses(initial);
          return initial;
        }
      } catch (e) {
        debugPrint('Firestore loadExpenses error: $e');
      }
    }

    // 2. Fallback to this user's private local cache (for offline use)
    final jsonString = prefs.getString(cacheKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final cached = decoded.map((e) => ExpenseItem.fromMap(e as Map<String, dynamic>)).toList();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {}
    }

    // 3. If neither Firestore nor local cache has data, initialize fresh empty table
    final initial = getInitialSeedData();
    await saveExpenses(initial);
    return initial;
  }

  Future<void> saveExpenses(List<ExpenseItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyExpenses);
    final jsonString = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString(cacheKey, jsonString);

    if (_userId != null && _userId!.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('expenses')
            .set({
              'items': items.map((e) => e.toMap()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        lastSyncError = null;
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('Firestore saveExpenses error: $e');
      }
    }
  }

  Future<List<ExpenseItem>> loadMonthlyDistributionExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyMonthlyDistribution);

    // 1. If signed in, query user's dedicated monthly distribution document
    if (_userId != null && _userId!.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('monthly_distribution')
            .get();

        if (doc.exists && doc.data() != null && doc.data()!['items'] != null) {
          final List<dynamic> firestoreItems = doc.data()!['items'] as List<dynamic>;
          final parsed = firestoreItems
              .map((e) => ExpenseItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (parsed.isNotEmpty) {
            await prefs.setString(cacheKey, jsonEncode(parsed.map((e) => e.toMap()).toList()));
            return parsed;
          }
        } else {
          // Brand new user -> Fresh empty monthly distribution
          final initial = getInitialSeedData(prefix: 'monthly-dist');
          await saveMonthlyDistributionExpenses(initial);
          return initial;
        }
      } catch (e) {
        debugPrint('Firestore loadMonthlyDistributionExpenses error: $e');
      }
    }

    // 2. Fallback to this user's private local cache
    final jsonString = prefs.getString(cacheKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final cached = decoded.map((e) => ExpenseItem.fromMap(e as Map<String, dynamic>)).toList();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {}
    }

    // 3. Initialize fresh empty monthly distribution
    final initial = getInitialSeedData(prefix: 'monthly-dist');
    await saveMonthlyDistributionExpenses(initial);
    return initial;
  }

  Future<void> saveMonthlyDistributionExpenses(List<ExpenseItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyMonthlyDistribution);
    final jsonString = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString(cacheKey, jsonString);

    if (_userId != null && _userId!.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('monthly_distribution')
            .set({
              'items': items.map((e) => e.toMap()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        lastSyncError = null;
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('Firestore saveMonthlyDistributionExpenses error: $e');
      }
    }
  }

  Future<double> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyBudget);

    if (_userId != null && _userId!.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('budget')
            .get();

        if (doc.exists && doc.data() != null && doc.data()!['amount'] != null) {
          final firestoreBudget = (doc.data()!['amount'] as num).toDouble();
          await prefs.setDouble(cacheKey, firestoreBudget);
          return firestoreBudget;
        } else {
          // Brand new user -> Default budget
          await saveBudget(defaultMonthlyBudget);
          return defaultMonthlyBudget;
        }
      } catch (e) {
        debugPrint('Firestore loadBudget error: $e');
      }
    }

    return prefs.getDouble(cacheKey) ?? defaultMonthlyBudget;
  }

  Future<void> saveBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _userKey(_baseKeyBudget);
    await prefs.setDouble(cacheKey, budget);

    if (_userId != null && _userId!.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('data')
            .doc('budget')
            .set({
              'amount': budget,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        lastSyncError = null;
      } catch (e) {
        lastSyncError = e.toString();
        debugPrint('Firestore saveBudget error: $e');
      }
    }
  }

  ExpenseItem createNewBlankItem({bool isPlaceholder = false}) {
    return ExpenseItem(
      id: _uuid.v4(),
      date: DateTime.now(),
      category: null,
      description: '',
      amount: 0.0,
      isPlaceholder: isPlaceholder,
      createdAt: DateTime.now(),
    );
  }
}
