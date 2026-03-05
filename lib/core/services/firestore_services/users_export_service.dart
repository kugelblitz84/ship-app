import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../download/download_service.dart';

class UsersExportService extends GetxService {
  UsersExportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final DownloadService _downloadService = createDownloadService();

  /// Exports every document and field from `users` collection to a JSON file.
  Future<GeneratedFileSaveResult> exportUsersToJsonFile() async {
    final users = await _fetchAllUsers();

    final payload = <String, dynamic>{
      "collection": "users",
      "exportedAt": DateTime.now().toIso8601String(),
      "count": users.length,
      "data": users,
    };

    final jsonString = const JsonEncoder.withIndent("  ").convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final fileName =
        'users_export_${DateTime.now().millisecondsSinceEpoch}.json';

    return _downloadService.saveFile(
      GeneratedFileData(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/json',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    final snapshot = await _firestore.collection("users").get();

    return snapshot.docs.map((doc) {
      return {
        "id": doc.id,
        "path": doc.reference.path,
        "data": _toJsonSafe(doc.data()),
      };
    }).toList();
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is GeoPoint) {
      return {"latitude": value.latitude, "longitude": value.longitude};
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is Blob) {
      return base64Encode(value.bytes);
    }

    if (value is Uint8List) {
      return base64Encode(value);
    }

    if (value is Iterable) {
      return value.map(_toJsonSafe).toList();
    }

    if (value is Map) {
      final mapped = <String, dynamic>{};
      for (final entry in value.entries) {
        mapped[entry.key.toString()] = _toJsonSafe(entry.value);
      }
      return mapped;
    }

    return value.toString();
  }
}
