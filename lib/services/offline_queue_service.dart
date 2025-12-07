import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/gps_location_data.dart';

/// Simple offline queue for GPSLocationData records.
///
/// Uses Hive under the hood to persist items between app launches.
class OfflineQueueService {
  static const _boxName = 'offline_location_queue';

  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Box<String>? _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      // We are storing as raw JSON strings, so no adapters required.
    }

    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<String>(_boxName);
    } else {
      _box = Hive.box<String>(_boxName);
    }
  }

  Future<void> enqueue(GPSLocationData data) async {
    await _ensureBox();
    final jsonString = jsonEncode(data.toJson());
    await _box!.add(jsonString);
  }

  Future<List<GPSLocationData>> getAll() async {
    await _ensureBox();
    return _box!.values
        .map((raw) => GPSLocationData.fromJson(jsonDecode(raw)))
        .toList();
  }

  Future<int> getCount() async {
    await _ensureBox();
    return _box!.length;
  }

  Future<void> removeAt(int index) async {
    await _ensureBox();
    await _box!.deleteAt(index);
  }

  Future<void> clear() async {
    await _ensureBox();
    await _box!.clear();
  }

  Future<void> _ensureBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
  }
}
